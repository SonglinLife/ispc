;;  Copyright (c) 2016-2025, Intel Corporation
;;
;;  SPDX-License-Identifier: BSD-3-Clause

define(`WIDTH',`4')
define(`ISA',`AVX512SKX')
define(`MASK',`i1')
define(`HAVE_GATHER',`1')
define(`HAVE_SCATTER',`1')

include(`target-avx512-utils.ll')

;; shuffles

declare <16 x i8> @llvm.x86.ssse3.pshuf.b.128(<16 x i8>, <16 x i8>)
define <4 x i8> @__shuffle_i8(<4 x i8> %data, <4 x i32> %shuffle_mask) nounwind readnone alwaysinline {
  convert4to16(i8, %data, %data16)

  ; Create mask (indices with high bit clear, 0x80 for zero)
  %shuffle_mask2 = trunc <4 x i32> %shuffle_mask to <4 x i8>
  %mask8 = shufflevector <4 x i8> %shuffle_mask2, <4 x i8> <i8 -128, i8 -128, i8 -128, i8 -128>,
                         <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %mask16 = shufflevector <8 x i8> %mask8, <8 x i8> <i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128>,
                         <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7,
                                    i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>

  ; Use vpshufb to perform the shuffle
  %result16 = call <16 x i8> @llvm.x86.ssse3.pshuf.b.128(<16 x i8> %data16, <16 x i8> %mask16)

  convert16to4(i8, %result16, %result)
  ret <4 x i8> %result
}

; Use vpermw to perform the shuffle of i16 vectors.
declare <8 x i16> @llvm.x86.avx512.mask.permvar.hi.128(<8 x i16>, <8 x i16>, <8 x i16>, i8)
define <4 x i16> @__shuffle_i16(<4 x i16> %src, <4 x i32> %indices) nounwind readnone alwaysinline {
  convert4to8(i16, %src, %src_ext)
  convert4to8(i32, %indices, %indices_ext)
  %ind = trunc <8 x i32> %indices_ext to <8 x i16>
  %res_ext = call <8 x i16> @llvm.x86.avx512.mask.permvar.hi.128(<8 x i16> %src_ext, <8 x i16> %ind, <8 x i16> zeroinitializer, i8 -1)
  convert8to4(i16, %res_ext, %result)
  ret <4 x i16> %result
}

define <4 x half> @__shuffle_half(<4 x half> %v, <4 x i32> %perm) nounwind readnone alwaysinline {
  %vals = bitcast <4 x half> %v to <4 x i16>
  %res = call <4 x i16> @__shuffle_i16(<4 x i16> %vals, <4 x i32> %perm)
  %res_half = bitcast <4 x i16> %res to <4 x half>
  ret <4 x half> %res_half
}

declare <WIDTH x float> @llvm.x86.avx512.mask.vpermilvar.ps.128(<WIDTH x float>, <WIDTH x i32>, <WIDTH x float>, i8)
define <WIDTH x float> @__shuffle_float(<WIDTH x float>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %res = call <WIDTH x float> @llvm.x86.avx512.mask.vpermilvar.ps.128(<WIDTH x float> %0, <WIDTH x i32> %1, <WIDTH x float> zeroinitializer, i8 -1)
  ret <WIDTH x float> %res
}

define <WIDTH x i32> @__shuffle_i32(<WIDTH x i32>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %input_fp = bitcast <WIDTH x i32> %0 to <WIDTH x float>
  %res_fp = call <WIDTH x float> @llvm.x86.avx512.mask.vpermilvar.ps.128(<WIDTH x float> %input_fp, <WIDTH x i32> %1, <WIDTH x float> zeroinitializer, i8 -1)
  %res = bitcast <WIDTH x float> %res_fp to <WIDTH x i32>
  ret <WIDTH x i32> %res
}

; Use vpermq to perform the shuffle of i64 vectors.
declare <WIDTH x i64> @llvm.x86.avx512.mask.permvar.di.256(<WIDTH x i64>, <WIDTH x i64>, <WIDTH x i64>, i8)
define <WIDTH x i64> @__shuffle_i64(<WIDTH x i64>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %ind = zext <WIDTH x i32> %1 to <WIDTH x i64>
  %res = call <WIDTH x i64> @llvm.x86.avx512.mask.permvar.di.256(<WIDTH x i64> %0, <WIDTH x i64> %ind, <WIDTH x i64> zeroinitializer, i8 -1)
  ret <WIDTH x i64> %res
}

declare <WIDTH x double> @llvm.x86.avx512.mask.permvar.df.256(<WIDTH x double>, <WIDTH x i64>, <WIDTH x double>, i8)
define <WIDTH x double> @__shuffle_double(<WIDTH x double>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %ind = zext <WIDTH x i32> %1 to <WIDTH x i64>
  %res = call <WIDTH x double> @llvm.x86.avx512.mask.permvar.df.256(<WIDTH x double> %0, <WIDTH x i64> %ind, <WIDTH x double> zeroinitializer, i8 -1)
  ret <WIDTH x double> %res
}

define_shuffle2_const()

define <4 x i8> @__shuffle2_i8(<4 x i8> %v1, <4 x i8> %v2, <4 x i32> %shuffle_mask) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<4 x i32> %shuffle_mask)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <4 x i8> @__shuffle2_const_i8(<4 x i8> %v1, <4 x i8> %v2, <4 x i32> %shuffle_mask)
  ret <4 x i8> %res_const

not_const:
  v4tov8(i8, %v1, %v2, %data8)
  convert8to16(i8, %data8, %data16)

  %shuffle_mask2 = trunc <4 x i32> %shuffle_mask to <4 x i8>
  %mask8 = shufflevector <4 x i8> %shuffle_mask2, <4 x i8> <i8 -128, i8 -128, i8 -128, i8 -128>,
                         <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %mask16 = shufflevector <8 x i8> %mask8, <8 x i8> <i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128, i8 -128>,
                         <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7,
                                    i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>

  ; Use vpshufb to perform the shuffle
  %result16 = call <16 x i8> @llvm.x86.ssse3.pshuf.b.128(<16 x i8> %data16, <16 x i8> %mask16)
  convert16to4(i8, %result16, %result)
  ret <4 x i8> %result
}

define <4 x i16> @__shuffle2_i16(<4 x i16> %v1, <4 x i16> %v2, <4 x i32> %shuffle_mask) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<4 x i32> %shuffle_mask)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <4 x i16> @__shuffle2_const_i16(<4 x i16> %v1, <4 x i16> %v2, <4 x i32> %shuffle_mask)
  ret <4 x i16> %res_const

not_const:
  v4tov8(i16, %v1, %v2, %data8)
  convert4to8(i32, %shuffle_mask, %mask8)
  %mask = trunc <8 x i32> %mask8 to <8 x i16>
  %result8 = call <8 x i16> @llvm.x86.avx512.mask.permvar.hi.128(<8 x i16> %data8, <8 x i16> %mask, <8 x i16> zeroinitializer, i8 -1)
  convert8to4(i16, %result8, %result)
  ret <4 x i16> %result
}

define <4 x half> @__shuffle2_half(<4 x half> %v1, <4 x half> %v2, <4 x i32> %shuffle_mask) nounwind readnone alwaysinline {
  %v1_i16 = bitcast <4 x half> %v1 to <4 x i16>
  %v2_i16 = bitcast <4 x half> %v2 to <4 x i16>
  %res_i16 = call <4 x i16> @__shuffle2_i16(<4 x i16> %v1_i16, <4 x i16> %v2_i16, <4 x i32> %shuffle_mask)
  %res_half = bitcast <4 x i16> %res_i16 to <4 x half>
  ret <4 x half> %res_half
}

declare <4 x i32> @llvm.x86.avx512.vpermi2var.d.128(<4 x i32>, <4 x i32>, <4 x i32>)
define <WIDTH x i32> @__shuffle2_i32(<WIDTH x i32>, <WIDTH x i32>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<WIDTH x i32> %2)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <WIDTH x i32> @__shuffle2_const_i32(<WIDTH x i32> %0, <WIDTH x i32> %1, <WIDTH x i32> %2)
  ret <WIDTH x i32> %res_const

not_const:
  %res = call <WIDTH x i32> @llvm.x86.avx512.vpermi2var.d.128(<WIDTH x i32> %0, <WIDTH x i32> %2, <WIDTH x i32> %1)
  ret <WIDTH x i32> %res
}

declare <4 x float> @llvm.x86.avx512.vpermi2var.ps.128(<4 x float>, <4 x i32>, <4 x float>)
define <WIDTH x float> @__shuffle2_float(<WIDTH x float>, <WIDTH x float>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<WIDTH x i32> %2)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <WIDTH x float> @__shuffle2_const_float(<WIDTH x float> %0, <WIDTH x float> %1, <WIDTH x i32> %2)
  ret <WIDTH x float> %res_const

not_const:
  %res = call <WIDTH x float> @llvm.x86.avx512.vpermi2var.ps.128(<WIDTH x float> %0, <WIDTH x i32> %2, <WIDTH x float> %1)
  ret <WIDTH x float> %res
}

declare <WIDTH x i64> @llvm.x86.avx512.vpermi2var.q.256(<WIDTH x i64>, <WIDTH x i64>, <WIDTH x i64>)
define <WIDTH x i64> @__shuffle2_i64(<WIDTH x i64>, <WIDTH x i64>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<WIDTH x i32> %2)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <WIDTH x i64> @__shuffle2_const_i64(<WIDTH x i64> %0, <WIDTH x i64> %1, <WIDTH x i32> %2)
  ret <WIDTH x i64> %res_const

not_const:
  %ind = zext <WIDTH x i32> %2 to <WIDTH x i64>
  %res = call <WIDTH x i64> @llvm.x86.avx512.vpermi2var.q.256(<WIDTH x i64> %0, <WIDTH x i64> %ind, <WIDTH x i64> %1)
  ret <WIDTH x i64> %res
}

declare <WIDTH x double> @llvm.x86.avx512.vpermi2var.pd.256(<WIDTH x double>, <WIDTH x i64>, <WIDTH x double>)
define <WIDTH x double> @__shuffle2_double(<WIDTH x double>, <WIDTH x double>, <WIDTH x i32>) nounwind readnone alwaysinline {
  %isc = call i1 @__is_compile_time_constant_varying_int32(<WIDTH x i32> %2)
  br i1 %isc, label %is_const, label %not_const

is_const:
  %res_const = tail call <WIDTH x double> @__shuffle2_const_double(<WIDTH x double> %0, <WIDTH x double> %1, <WIDTH x i32> %2)
  ret <WIDTH x double> %res_const

not_const:
  %ind = zext <WIDTH x i32> %2 to <WIDTH x i64>
  %res = call <WIDTH x double> @llvm.x86.avx512.vpermi2var.pd.256(<WIDTH x double> %0, <WIDTH x i64> %ind, <WIDTH x double> %1)
  ret <WIDTH x double> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Stub for mask conversion. LLVM's intrinsics want i1 mask, but we use i8

define i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask) alwaysinline {
  %mask_i4 = bitcast <WIDTH x i1> %mask to i4
  %mask_i8 = zext i4 %mask_i4 to i8
  ret i8 %mask_i8
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; half conversion routines

declare <4 x float> @llvm.x86.vcvtph2ps.128(<4 x i16>) nounwind readnone
declare <8 x i16> @llvm.x86.vcvtps2ph.128(<4 x float>, i32) nounwind readnone
declare <8 x float> @llvm.x86.vcvtph2ps.256(<8 x i16>) nounwind readnone
declare <8 x i16> @llvm.x86.vcvtps2ph.256(<8 x float>, i32) nounwind readnone

define <4 x float> @__half_to_float_varying(<4 x i16> %v) nounwind readnone {
  %r = call <4 x float> @llvm.x86.vcvtph2ps.128(<4 x i16> %v)
  ret <4 x float> %r
}

define <4 x i16> @__float_to_half_varying(<4 x float> %v) nounwind readnone {
  %r = call <8 x i16> @llvm.x86.vcvtps2ph.128(<4 x float> %v, i32 0)
  %res = shufflevector <8 x i16> %r, <8 x i16> undef, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  ret <4 x i16> %res
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding floats

declare <4 x float> @llvm.roundeven.v4f32(<4 x float> %p)
declare <4 x float> @llvm.floor.v4f32(<4 x float> %p)
declare <4 x float> @llvm.ceil.v4f32(<4 x float> %p)

define <4 x float> @__round_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.roundeven.v4f32(<4 x float> %0)
  ret <4 x float> %res
}

define <4 x float> @__floor_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.floor.v4f32(<4 x float> %0)
  ret <4 x float> %res
}

define <4 x float> @__ceil_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.ceil.v4f32(<4 x float> %0)
  ret <4 x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding doubles

declare <4 x double> @llvm.roundeven.v4f64(<4 x double> %p)
declare <4 x double> @llvm.floor.v4f64(<4 x double> %p)
declare <4 x double> @llvm.ceil.v4f64(<4 x double> %p)

define <4 x double> @__round_varying_double(<4 x double>) nounwind readonly alwaysinline {
  %res = call <4 x double> @llvm.roundeven.v4f64(<4 x double> %0)
  ret <4 x double> %res
}

define <4 x double> @__floor_varying_double(<4 x double>) nounwind readonly alwaysinline {
  %res = call <4 x double> @llvm.floor.v4f64(<4 x double> %0)
  ret <4 x double> %res
}

define <4 x double> @__ceil_varying_double(<4 x double>) nounwind readonly alwaysinline {
  %res = call <4 x double> @llvm.ceil.v4f64(<4 x double> %0)
  ret <4 x double> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; trunc float and double

truncate()

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; min/max

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; int64/uint64 min/max

declare <4 x i64> @llvm.x86.avx512.mask.pmaxs.q.256(<4 x i64>, <4 x i64>, <4 x i64>, i8)
declare <4 x i64> @llvm.x86.avx512.mask.pmaxu.q.256(<4 x i64>, <4 x i64>, <4 x i64>, i8)
declare <4 x i64> @llvm.x86.avx512.mask.pmins.q.256(<4 x i64>, <4 x i64>, <4 x i64>, i8)
declare <4 x i64> @llvm.x86.avx512.mask.pminu.q.256(<4 x i64>, <4 x i64>, <4 x i64>, i8)

define <4 x i64> @__max_varying_int64(<4 x i64>, <4 x i64>) nounwind readonly alwaysinline {
  %res = call <4 x i64> @llvm.x86.avx512.mask.pmaxs.q.256(<4 x i64> %0, <4 x i64> %1, <4 x i64>zeroinitializer, i8 -1)
  ret <4 x i64> %res
}

define <4 x i64> @__max_varying_uint64(<4 x i64>, <4 x i64>) nounwind readonly alwaysinline {
  %res = call <4 x i64> @llvm.x86.avx512.mask.pmaxu.q.256(<4 x i64> %0, <4 x i64> %1, <4 x i64>zeroinitializer, i8 -1)
  ret <4 x i64> %res
}

define <4 x i64> @__min_varying_int64(<4 x i64>, <4 x i64>) nounwind readonly alwaysinline {
  %res = call <4 x i64> @llvm.x86.avx512.mask.pmins.q.256(<4 x i64> %0, <4 x i64> %1, <4 x i64>zeroinitializer, i8 -1)
  ret <4 x i64> %res
}

define <4 x i64> @__min_varying_uint64(<4 x i64>, <4 x i64>) nounwind readonly alwaysinline {
  %res = call <4 x i64> @llvm.x86.avx512.mask.pminu.q.256(<4 x i64> %0, <4 x i64> %1, <4 x i64>zeroinitializer, i8 -1)
  ret <4 x i64> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; float min/max

declare <4 x float> @llvm.x86.avx512.mask.max.ps.128(<4 x float>, <4 x float>, <4 x float>, i8)
declare <4 x float> @llvm.x86.avx512.mask.min.ps.128(<4 x float>, <4 x float>, <4 x float>, i8)

define <4 x float> @__max_varying_float(<4 x float>, <4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.x86.avx512.mask.max.ps.128(<4 x float> %0, <4 x float> %1, <4 x float>zeroinitializer, i8 -1)
  ret <4 x float> %res
}

define <4 x float> @__min_varying_float(<4 x float>, <4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.x86.avx512.mask.min.ps.128(<4 x float> %0, <4 x float> %1, <4 x float>zeroinitializer, i8 -1)
  ret <4 x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unsigned int min/max

declare <4 x i32> @llvm.x86.avx512.mask.pmins.d.128(<4 x i32>, <4 x i32>, <4 x i32>, i8)
declare <4 x i32> @llvm.x86.avx512.mask.pmaxs.d.128(<4 x i32>, <4 x i32>, <4 x i32>, i8)

define <4 x i32> @__min_varying_int32(<4 x i32>, <4 x i32>) nounwind readonly alwaysinline {
  %ret = call <4 x i32> @llvm.x86.avx512.mask.pmins.d.128(<4 x i32> %0, <4 x i32> %1, 
                                                           <4 x i32> zeroinitializer, i8 -1)
  ret <4 x i32> %ret
}

define <4 x i32> @__max_varying_int32(<4 x i32>, <4 x i32>) nounwind readonly alwaysinline {
  %ret = call <4 x i32> @llvm.x86.avx512.mask.pmaxs.d.128(<4 x i32> %0, <4 x i32> %1,
                                                           <4 x i32> zeroinitializer, i8 -1)
  ret <4 x i32> %ret
}

declare <4 x i32> @llvm.x86.avx512.mask.pminu.d.128(<4 x i32>, <4 x i32>, <4 x i32>, i8)
declare <4 x i32> @llvm.x86.avx512.mask.pmaxu.d.128(<4 x i32>, <4 x i32>, <4 x i32>, i8)

define <4 x i32> @__min_varying_uint32(<4 x i32>, <4 x i32>) nounwind readonly alwaysinline {
  %ret = call <4 x i32> @llvm.x86.avx512.mask.pminu.d.128(<4 x i32> %0, <4 x i32> %1,
                                                           <4 x i32> zeroinitializer, i8 -1)
  ret <4 x i32> %ret
}

define <4 x i32> @__max_varying_uint32(<4 x i32>, <4 x i32>) nounwind readonly alwaysinline {
  %ret = call <4 x i32> @llvm.x86.avx512.mask.pmaxu.d.128(<4 x i32> %0, <4 x i32> %1,
                                                           <4 x i32> zeroinitializer, i8 -1)
  ret <4 x i32> %ret
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double precision min/max

declare <4 x double> @llvm.x86.avx512.mask.min.pd.128(<4 x double>, <4 x double>, <4 x double>, i8)
declare <4 x double> @llvm.x86.avx512.mask.max.pd.128(<4 x double>, <4 x double>, <4 x double>, i8)

define <4 x double> @__min_varying_double(<4 x double>, <4 x double>) nounwind readnone alwaysinline {
  %res = call <4 x double> @llvm.x86.avx512.mask.min.pd.128(<4 x double> %0, <4 x double> %1, <4 x double> zeroinitializer, i8 -1)
  ret <4 x double> %res                       
}

define <4 x double> @__max_varying_double(<4 x double>, <4 x double>) nounwind readnone alwaysinline {
  %res = call <4 x double> @llvm.x86.avx512.mask.max.pd.128(<4 x double> %0, <4 x double> %1, <4 x double> zeroinitializer, i8 -1)
  ret <4 x double> %res 
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sqrt

declare <4 x float> @llvm.x86.avx512.mask.sqrt.ps.128(<4 x float>, <4 x float>, i8) nounwind readnone

define <4 x float> @__sqrt_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %res = call <4 x float> @llvm.x86.avx512.mask.sqrt.ps.128(<4 x float> %0, <4 x float> zeroinitializer, i8 -1)
  ret <4 x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double precision sqrt

declare <2 x double> @llvm.x86.sse2.sqrt.sd(<2 x double>) nounwind readnone

define double @__sqrt_uniform_double(double) nounwind alwaysinline {
  sse_unary_scalar(ret, 2, double, @llvm.x86.sse2.sqrt.sd, %0)
  ret double %ret
}

declare <4 x double> @llvm.x86.avx512.mask.sqrt.pd.256(<4 x double>, <4 x double>, i8) nounwind readnone

define <4 x double> @__sqrt_varying_double(<4 x double>) nounwind alwaysinline {
  %res = call <4 x double> @llvm.x86.avx512.mask.sqrt.pd.256(<4 x double> %0,  <4 x double> zeroinitializer, i8 -1)
  ret <4 x double> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; svml

include(`svml.m4')
svml(ISA)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reductions

define i64 @__movmsk(<WIDTH x MASK> %mask) nounwind readnone alwaysinline {
  %intmask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = zext i8 %intmask to i64
  ret i64 %res
}

define i1 @__any(<WIDTH x MASK> %mask) nounwind readnone alwaysinline {
  %intmask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = icmp ne i8 %intmask, 0
  ret i1 %res
}

define i1 @__all(<WIDTH x MASK> %mask) nounwind readnone alwaysinline {
  %intmask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = icmp eq i8 %intmask, 15
  ret i1 %res
}

define i1 @__none(<WIDTH x MASK> %mask) nounwind readnone alwaysinline {
  %intmask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = icmp eq i8 %intmask, 0
  ret i1 %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal int8/16 ops

declare <2 x i64> @llvm.x86.sse2.psad.bw(<16 x i8>, <16 x i8>) nounwind readnone

define i16 @__reduce_add_int8(<4 x i8>) nounwind readnone alwaysinline {
  %ri = shufflevector <4 x i8> %0, <4 x i8> zeroinitializer,
                         <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7,
                         i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7>
  %rv = call <2 x i64> @llvm.x86.sse2.psad.bw(<16 x i8> %ri,
                                              <16 x i8> zeroinitializer)
  %r = extractelement <2 x i64> %rv, i32 0
  %r16 = trunc i64 %r to i16
  ret i16 %r16
}

define internal <4 x i16> @__add_varying_i16(<4 x i16>,
                                  <4 x i16>) nounwind readnone alwaysinline {
  %r = add <4 x i16> %0, %1
  ret <4 x i16> %r
}

define internal i16 @__add_uniform_i16(i16, i16) nounwind readnone alwaysinline {
  %r = add i16 %0, %1
  ret i16 %r
}

define i16 @__reduce_add_int16(<4 x i16>) nounwind readnone alwaysinline {
  reduce4(i16, @__add_varying_i16, @__add_uniform_i16)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal float ops

declare <4 x float> @llvm.x86.sse3.hadd.ps(<4 x float>, <4 x float>) nounwind readnone

define float @__reduce_add_float(<4 x float>) nounwind readonly alwaysinline {
  %v1 = call <4 x float> @llvm.x86.sse3.hadd.ps(<4 x float> %0, <4 x float> %0)
  %v2 = call <4 x float> @llvm.x86.sse3.hadd.ps(<4 x float> %v1, <4 x float> %v1)
  %sum = extractelement <4 x float> %v2, i32 0
  ret float %sum
}

define float @__reduce_min_float(<4 x float>) nounwind readnone alwaysinline {
  reduce4(float, @__min_varying_float, @__min_uniform_float)
}

define float @__reduce_max_float(<4 x float>) nounwind readnone alwaysinline {
  reduce4(float, @__max_varying_float, @__max_uniform_float)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal int32 ops

define internal <4 x i32> @__add_varying_int32(<4 x i32>, <4 x i32>) nounwind readnone alwaysinline {
  %s = add <4 x i32> %0, %1
  ret <4 x i32> %s
}

define internal i32 @__add_uniform_int32(i32, i32) nounwind readnone alwaysinline {
  %s = add i32 %0, %1
  ret i32 %s
}

define i32 @__reduce_add_int32(<4 x i32>) nounwind readnone alwaysinline {
  reduce4(i32, @__add_varying_int32, @__add_uniform_int32)
}

define i32 @__reduce_min_int32(<4 x i32>) nounwind readnone alwaysinline {
  reduce4(i32, @__min_varying_int32, @__min_uniform_int32)
}

define i32 @__reduce_max_int32(<4 x i32>) nounwind readnone alwaysinline {
  reduce4(i32, @__max_varying_int32, @__max_uniform_int32)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; horizontal uint32 ops

define i32 @__reduce_min_uint32(<4 x i32>) nounwind readnone alwaysinline {
  reduce4(i32, @__min_varying_uint32, @__min_uniform_uint32)
}

define i32 @__reduce_max_uint32(<4 x i32>) nounwind readnone alwaysinline {
  reduce4(i32, @__max_varying_uint32, @__max_uniform_uint32)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal double ops

declare <4 x double> @llvm.x86.avx.hadd.pd.256(<4 x double>, <4 x double>) nounwind readnone

define double @__reduce_add_double(<4 x double>) nounwind readonly alwaysinline {
  %sum0 = call <4 x double> @llvm.x86.avx.hadd.pd.256(<4 x double> %0, <4 x double> %0)
  %final0 = extractelement <4 x double> %sum0, i32 0
  %final1 = extractelement <4 x double> %sum0, i32 2
  %sum = fadd double %final0, %final1
  ret double %sum
}

define double @__reduce_min_double(<4 x double>) nounwind readnone alwaysinline {
  reduce4(double, @__min_varying_double, @__min_uniform_double)
}

define double @__reduce_max_double(<4 x double>) nounwind readnone alwaysinline {
  reduce4(double, @__max_varying_double, @__max_uniform_double)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal int64 ops

define internal <4 x i64> @__add_varying_int64(<4 x i64>, <4 x i64>) nounwind readnone alwaysinline {
  %s = add <4 x i64> %0, %1
  ret <4 x i64> %s
}

define internal i64 @__add_uniform_int64(i64, i64) nounwind readnone alwaysinline {
  %s = add i64 %0, %1
  ret i64 %s
}

define i64 @__reduce_add_int64(<4 x i64>) nounwind readnone alwaysinline {
  reduce4(i64, @__add_varying_int64, @__add_uniform_int64)
}

define i64 @__reduce_min_int64(<4 x i64>) nounwind readnone alwaysinline {
  reduce4(i64, @__min_varying_int64, @__min_uniform_int64)
}

define i64 @__reduce_max_int64(<4 x i64>) nounwind readnone alwaysinline {
  reduce4(i64, @__max_varying_int64, @__max_uniform_int64)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; horizontal uint64 ops

define i64 @__reduce_min_uint64(<4 x i64>) nounwind readnone alwaysinline {
  reduce4(i64, @__min_varying_uint64, @__min_uniform_uint64)
}

define i64 @__reduce_max_uint64(<4 x i64>) nounwind readnone alwaysinline {
  reduce4(i64, @__max_varying_uint64, @__max_uniform_uint64)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unaligned loads/loads+broadcasts

masked_load(i8,  1)
masked_load(i16, 2)
masked_load(half, 2)

declare <4 x i32> @llvm.x86.avx512.mask.loadu.d.128(i8*, <4 x i32>, i8)
define <4 x i32> @__masked_load_i32(i8 * %ptr, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = call <4 x i32> @llvm.x86.avx512.mask.loadu.d.128(i8* %ptr, <4 x i32> zeroinitializer, i8 %mask_i8)
  ret <4 x i32> %res
}

declare <4 x i64> @llvm.x86.avx512.mask.loadu.q.256(i8*, <4 x i64>, i8)
define <4 x i64> @__masked_load_i64(i8 * %ptr, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = call <4 x i64> @llvm.x86.avx512.mask.loadu.q.256(i8* %ptr, <4 x i64> zeroinitializer, i8 %mask_i8)
  ret <4 x i64> %res
}

declare <4 x float> @llvm.x86.avx512.mask.loadu.ps.128(i8*, <4 x float>, i8)
define <4 x float> @__masked_load_float(i8 * %ptr, <WIDTH x MASK> %mask) readonly alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = call <4 x float> @llvm.x86.avx512.mask.loadu.ps.128(i8* %ptr, <4 x float> zeroinitializer, i8 %mask_i8)
  ret <4 x float> %res
}

declare <4 x double> @llvm.x86.avx512.mask.loadu.pd.256(i8*, <4 x double>, i8)
define <4 x double> @__masked_load_double(i8 * %ptr, <WIDTH x MASK> %mask) readonly alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %res = call <4 x double> @llvm.x86.avx512.mask.loadu.pd.256(i8* %ptr, <4 x double> zeroinitializer, i8 %mask_i8)
  ret <4 x double> %res
}


gen_masked_store(i8) ; llvm.x86.sse2.storeu.dq
gen_masked_store(i16)
gen_masked_store(half)

declare void @llvm.x86.avx512.mask.storeu.d.128(i8*, <4 x i32>, i8)
define void @__masked_store_i32(<4 x i32>* nocapture, <4 x i32> %v, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %ptr_i8 = bitcast <4 x i32>* %0 to i8*
  call void @llvm.x86.avx512.mask.storeu.d.128(i8* %ptr_i8, <4 x i32> %v, i8 %mask_i8)
  ret void
}

declare void @llvm.x86.avx512.mask.storeu.q.256(i8*, <4 x i64>, i8)
define void @__masked_store_i64(<4 x i64>* nocapture, <4 x i64> %v, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %ptr_i8 = bitcast <4 x i64>* %0 to i8*
  call void @llvm.x86.avx512.mask.storeu.q.256(i8* %ptr_i8, <4 x i64> %v, i8 %mask_i8)
  ret void
}

declare void @llvm.x86.avx512.mask.storeu.ps.128(i8*, <4 x float>, i8)
define void @__masked_store_float(<4 x float>* nocapture, <4 x float> %v, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %ptr_i8 = bitcast <4 x float>* %0 to i8*
  call void @llvm.x86.avx512.mask.storeu.ps.128(i8* %ptr_i8, <4 x float> %v, i8 %mask_i8)
  ret void
}

declare void @llvm.x86.avx512.mask.storeu.pd.256(i8*, <4 x double>, i8)
define void @__masked_store_double(<4 x double>* nocapture, <4 x double> %v, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %mask_i8 = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %mask)
  %ptr_i8 = bitcast <4 x double>* %0 to i8*
  call void @llvm.x86.avx512.mask.storeu.pd.256(i8* %ptr_i8, <4 x double> %v, i8 %mask_i8)
  ret void
}

define void @__masked_store_blend_i8(<4 x i8>* nocapture, <4 x i8>,
                                     <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x i8> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x i8> %1, <4 x i8> %v
  store <4 x i8> %v1, <4 x i8> * %0
  ret void
}

define void @__masked_store_blend_i16(<4 x i16>* nocapture, <4 x i16>,
                                      <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x i16> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x i16> %1, <4 x i16> %v
  store <4 x i16> %v1, <4 x i16> * %0
  ret void
}

define void @__masked_store_blend_half(<4 x half>* nocapture, <4 x half>,
                                        <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x half> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x half> %1, <4 x half> %v
  store <4 x half> %v1, <4 x half> * %0
  ret void
}

define void @__masked_store_blend_i32(<4 x i32>* nocapture, <4 x i32>,
                                      <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x i32> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x i32> %1, <4 x i32> %v
  store <4 x i32> %v1, <4 x i32> * %0
  ret void
}

define void @__masked_store_blend_float(<4 x float>* nocapture, <4 x float>, 
                                        <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x float> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x float> %1, <4 x float> %v
  store <4 x float> %v1, <4 x float> * %0
  ret void
}

define void @__masked_store_blend_i64(<4 x i64>* nocapture,
                            <4 x i64>, <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x i64> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x i64> %1, <4 x i64> %v
  store <4 x i64> %v1, <4 x i64> * %0
  ret void
}

define void @__masked_store_blend_double(<4 x double>* nocapture,
                            <4 x double>, <WIDTH x MASK>) nounwind alwaysinline {
  %v = load PTR_OP_ARGS(`<4 x double> ')  %0
  %v1 = select <WIDTH x i1> %2, <4 x double> %1, <4 x double> %v
  store <4 x double> %v1, <4 x double> * %0
  ret void
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gather/scatter

;; We need factored generic implementations when --opt=disable-gathers is used.
;; The util functions for gathers already include factored implementations,
;; so use factored ones here explicitely for remaining types only.

;; gather - i8
gen_gather(i8)

;; gather - i16
gen_gather(i16)

;; gather - half
gen_gather(half)

gen_gather_factored_generic(i32)
gen_gather_factored_generic(float)
gen_gather_factored_generic(i64)
gen_gather_factored_generic(double)

;; gather - i32
declare <4 x i32> @llvm.x86.avx512.gather3siv4.si(<4 x i32>, i8*, <4 x i32>, i8, i32)
define <4 x i32>
@__gather_base_offsets32_i32(i8 * %ptr, i32 %offset_scale, <4 x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_gather(res, llvm.x86.avx512.gather3siv4.si, 4, i32, ptr, offsets, i32, mask, i8, offset_scale)
  ret <4 x i32> %res
}

declare <4 x i32> @llvm.x86.avx512.gather3div8.si(<4 x i32>, i8*, <4 x i64>, i8, i32)
define <4 x i32>
@__gather_base_offsets64_i32(i8 * %ptr, i32 %offset_scale, <4 x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %scalarMask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_gather(res, llvm.x86.avx512.gather3div8.si, 4, i32, ptr, offsets, i64, scalarMask, i8, offset_scale)
  ret <4 x i32> %res
}

define <4 x i32>
@__gather32_i32(<4 x i32> %ptrs, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x i32> @__gather_base_offsets32_i32(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <WIDTH x MASK> %vecmask)
  ret <4 x i32> %res
}

define <4 x i32>
@__gather64_i32(<4 x i64> %ptrs, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x i32> @__gather_base_offsets64_i32(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <WIDTH x MASK> %vecmask)
  ret <4 x i32> %res
}

;; gather - i64
declare <4 x i64> @llvm.x86.avx512.mask.gather3siv4.di(<4 x i64>, i8*, <4 x i32>, <4 x i1>, i32)
define <4 x i64>
@__gather_base_offsets32_i64(i8 * %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  convert_scale_to_const_gather(res, llvm.x86.avx512.mask.gather3siv4.di, 4, i64, ptr, offsets, i32, vecmask, <4 x i1>, offset_scale)
  ret <4 x i64> %res
}

declare <4 x i64> @llvm.x86.avx512.mask.gather3div4.di(<4 x i64>, i8*, <4 x i64>, <4 x i1>, i32)
define <4 x i64>
@__gather_base_offsets64_i64(i8 * %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  convert_scale_to_const_gather(res, llvm.x86.avx512.mask.gather3div4.di, 4, i64, ptr, offsets, i64, vecmask, <4 x i1>, offset_scale)
  ret <4 x i64> %res
}

define <4 x i64>
@__gather32_i64(<4 x i32> %ptrs, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x i64> @__gather_base_offsets32_i64(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x i1> %vecmask)
  ret <4 x i64> %res
}

define <4 x i64>
@__gather64_i64(<4 x i64> %ptrs, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x i64> @__gather_base_offsets64_i64(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x i1> %vecmask)
  ret <4 x i64> %res
}

;; gather - float
declare <4 x float> @llvm.x86.avx512.gather3siv4.sf(<4 x float>, i8*, <4 x i32>, i8, i32)
define <4 x float>
@__gather_base_offsets32_float(i8 * %ptr, i32 %offset_scale, <4 x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_gather(res, llvm.x86.avx512.gather3siv4.sf, 4, float, ptr, offsets, i32, mask, i8, offset_scale)
  ret <4 x float> %res
}

declare <4 x float> @llvm.x86.avx512.gather3div8.sf(<4 x float>, i8*, <4 x i64>, i8, i32)
define <4 x float>
@__gather_base_offsets64_float(i8 * %ptr, i32 %offset_scale, <4 x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_gather(res, llvm.x86.avx512.gather3div8.sf, 4, float, ptr, offsets, i64, mask, i8, offset_scale)
  ret <4 x float> %res
}

define <4 x float>
@__gather32_float(<4 x i32> %ptrs, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x float> @__gather_base_offsets32_float(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <WIDTH x MASK> %vecmask)
  ret <4 x float> %res
}

define <4 x float>
@__gather64_float(<4 x i64> %ptrs,  <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x float> @__gather_base_offsets64_float(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <WIDTH x MASK> %vecmask)
  ret <4 x float> %res
}

;; gather - double
declare <4 x double> @llvm.x86.avx512.mask.gather3siv4.df(<4 x double>, i8*, <4 x i32>, <4 x i1>, i32)
define <4 x double>
@__gather_base_offsets32_double(i8 * %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  convert_scale_to_const_gather(res, llvm.x86.avx512.mask.gather3siv4.df, 4, double, ptr, offsets, i32, vecmask, <4 x i1>, offset_scale)
  ret <4 x double> %res
}

declare <4 x double> @llvm.x86.avx512.mask.gather3div4.df(<4 x double>, i8*, <4 x i64>, <4 x i1>, i32)
define <4 x double>
@__gather_base_offsets64_double(i8 * %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  convert_scale_to_const_gather(res, llvm.x86.avx512.mask.gather3div4.df, 4, double, ptr, offsets, i64, vecmask, <4 x i1>, offset_scale)
  ret <4 x double> %res
}

define <4 x double>
@__gather32_double(<4 x i32> %ptrs, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x double> @__gather_base_offsets32_double(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x i1> %vecmask)
  ret <4 x double> %res
}

define <4 x double>
@__gather64_double(<4 x i64> %ptrs, <4 x i1> %vecmask) nounwind readonly alwaysinline {
  %res = call <4 x double> @__gather_base_offsets64_double(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x i1> %vecmask)
  ret <4 x double> %res
}


define(`scatterbo32_64', `
define void @__scatter_base_offsets32_$1(i8* %ptr, i32 %scale, <WIDTH x i32> %offsets,
                                         <WIDTH x $1> %vals, <WIDTH x MASK> %mask) nounwind {
  call void @__scatter_factored_base_offsets32_$1(i8* %ptr, <WIDTH x i32> %offsets,
      i32 %scale, <WIDTH x i32> zeroinitializer, <WIDTH x $1> %vals, <WIDTH x MASK> %mask)
  ret void
}

define void @__scatter_base_offsets64_$1(i8* %ptr, i32 %scale, <WIDTH x i64> %offsets,
                                         <WIDTH x $1> %vals, <WIDTH x MASK> %mask) nounwind {
  call void @__scatter_factored_base_offsets64_$1(i8* %ptr, <WIDTH x i64> %offsets,
      i32 %scale, <WIDTH x i64> zeroinitializer, <WIDTH x $1> %vals, <WIDTH x MASK> %mask)
  ret void
}
')

;; We need factored generic implementations when --opt=disable-scatters is used.
;; The util functions for scatters already include factored implementations,
;; so use factored ones here explicitely for remaining types only.

;; scatter - i8
scatterbo32_64(i8)
gen_scatter(i8)

;; scatter - i16
scatterbo32_64(i16)
gen_scatter(i16)

;; scatter - half
scatterbo32_64(half)
gen_scatter(half)

gen_scatter_factored(i32)
gen_scatter_factored(float)
gen_scatter_factored(i64)
gen_scatter_factored(double)

;; scatter - i32
declare void @llvm.x86.avx512.scattersiv4.si(i8*, i8, <4 x i32>, <4 x i32>, i32)
define void
@__scatter_base_offsets32_i32(i8* %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x i32> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_scatter(llvm.x86.avx512.scattersiv4.si, 4, vals, i32, ptr, offsets, i32, mask, i8, offset_scale);
  ret void
}

declare void @llvm.x86.avx512.scatterdiv8.si(i8*, i8, <4 x i64>, <4 x i32>, i32)
define void
@__scatter_base_offsets64_i32(i8* %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x i32> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_scatter(llvm.x86.avx512.scatterdiv8.si, 4, vals, i32, ptr, offsets, i64, mask, i8, offset_scale);
  ret void
} 

define void
@__scatter32_i32(<4 x i32> %ptrs, <4 x i32> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets32_i32(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x i32> %values, <WIDTH x MASK> %vecmask)
  ret void
}

define void
@__scatter64_i32(<4 x i64> %ptrs, <4 x i32> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets64_i32(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x i32> %values, <WIDTH x MASK> %vecmask)
  ret void
}

;; scatter - i64
declare void @llvm.x86.avx512.mask.scattersiv4.di(i8*, <4 x i1>, <4 x i32>, <4 x i64>, i32)
define void
@__scatter_base_offsets32_i64(i8* %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x i64> %vals, <4 x i1> %vecmask) nounwind {
  convert_scale_to_const_scatter(llvm.x86.avx512.mask.scattersiv4.di, 4, vals, i64, ptr, offsets, i32, vecmask, <4 x i1>, offset_scale);
  ret void
}

declare void @llvm.x86.avx512.mask.scatterdiv4.di(i8*, <4 x i1>, <4 x i64>, <4 x i64>, i32)
define void
@__scatter_base_offsets64_i64(i8* %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x i64> %vals, <4 x i1> %vecmask) nounwind {
  convert_scale_to_const_scatter(llvm.x86.avx512.mask.scatterdiv4.di, 4, vals, i64, ptr, offsets, i64, vecmask, <4 x i1>, offset_scale);
  ret void
}

define void
@__scatter32_i64(<4 x i32> %ptrs, <4 x i64> %values, <4 x i1> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets32_i64(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x i64> %values, <4 x i1> %vecmask)
  ret void
}

define void
@__scatter64_i64(<4 x i64> %ptrs, <4 x i64> %values, <4 x i1> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets64_i64(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x i64> %values, <4 x i1> %vecmask)
  ret void
}

;; scatter - float
declare void @llvm.x86.avx512.scattersiv4.sf(i8*, i8, <4 x i32>, <4 x float>, i32)
define void
@__scatter_base_offsets32_float(i8* %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x float> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_scatter(llvm.x86.avx512.scattersiv4.sf, 4, vals, float, ptr, offsets, i32, mask, i8, offset_scale);
  ret void
}

declare void @llvm.x86.avx512.scatterdiv8.sf(i8*, i8, <4 x i64>, <4 x float>, i32)
define void
@__scatter_base_offsets64_float(i8* %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x float> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %mask = call i8 @__cast_mask_to_i8 (<WIDTH x MASK> %vecmask)
  convert_scale_to_const_scatter(llvm.x86.avx512.scatterdiv8.sf, 4, vals, float, ptr, offsets, i64, mask, i8, offset_scale);
  ret void
} 

define void 
@__scatter32_float(<4 x i32> %ptrs, <4 x float> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets32_float(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x float> %values, <WIDTH x MASK> %vecmask)
  ret void
}

define void 
@__scatter64_float(<4 x i64> %ptrs, <4 x float> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets64_float(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x float> %values, <WIDTH x MASK> %vecmask)
  ret void
}

;; scatter - double
declare void @llvm.x86.avx512.mask.scattersiv4.df(i8*, <4 x i1>, <4 x i32>, <4 x double>, i32)
define void
@__scatter_base_offsets32_double(i8* %ptr, i32 %offset_scale, <4 x i32> %offsets, <4 x double> %vals, <4 x i1> %vecmask) nounwind {
  convert_scale_to_const_scatter(llvm.x86.avx512.mask.scattersiv4.df, 4, vals, double, ptr, offsets, i32, vecmask, <4 x i1>, offset_scale);
  ret void
}

declare void @llvm.x86.avx512.mask.scatterdiv4.df(i8*, <4 x i1>, <4 x i64>, <4 x double>, i32)
define void
@__scatter_base_offsets64_double(i8* %ptr, i32 %offset_scale, <4 x i64> %offsets, <4 x double> %vals, <4 x i1> %vecmask) nounwind {
  convert_scale_to_const_scatter(llvm.x86.avx512.mask.scatterdiv4.df, 4, vals, double, ptr, offsets, i64, vecmask, <4 x i1>, offset_scale);
  ret void
}

define void
@__scatter32_double(<4 x i32> %ptrs, <4 x double> %values, <4 x i1> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets32_double(i8 * zeroinitializer, i32 1, <4 x i32> %ptrs, <4 x double> %values, <4 x i1> %vecmask)
  ret void
}

define void
@__scatter64_double(<4 x i64> %ptrs, <4 x double> %values, <4 x i1> %vecmask) nounwind alwaysinline {
  call void @__scatter_base_offsets64_double(i8 * zeroinitializer, i32 1, <4 x i64> %ptrs, <4 x double> %values, <4 x i1> %vecmask)
  ret void
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; packed_load/store
packed_load_and_store(TRUE)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; prefetch

define_prefetches()

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; int8/int16 builtins

define_avgs()

;; Trigonometry

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rcp/rsqrt declarations for half

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rcp, rsqrt

rcp14_uniform()
;; rcp float
declare <4 x float> @llvm.x86.avx512.rcp14.ps.128(<4 x float>, <4 x float>, i8) nounwind readnone
define <4 x float> @__rcp_fast_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %ret = call <4 x float> @llvm.x86.avx512.rcp14.ps.128(<4 x float> %0, <4 x float> undef, i8 -1)
  ret <4 x float> %ret
}
define <4 x float> @__rcp_varying_float(<4 x float>) nounwind readonly alwaysinline {
  %call = call <4 x float> @__rcp_fast_varying_float(<4 x float> %0)
  ;; do one Newton-Raphson iteration to improve precision
  ;;  float iv = __rcp_v(v);
  ;;  return iv * (2. - v * iv);
  %v_iv = fmul <4 x float> %0, %call
  %two_minus = fsub <4 x float> <float 2., float 2., float 2., float 2.>, %v_iv
  %iv_mul = fmul <4 x float> %call,  %two_minus
  ret <4 x float> %iv_mul
}

;; rcp double
declare <4 x double> @llvm.x86.avx512.rcp14.pd.256(<4 x double>, <4 x double>, i8) nounwind readnone
define <4 x double> @__rcp_fast_varying_double(<4 x double> %val) nounwind readonly alwaysinline {
  %res = call <4 x double> @llvm.x86.avx512.rcp14.pd.256(<4 x double> %val, <4 x double> undef, i8 -1)
  ret <4 x double> %res
}
define <4 x double> @__rcp_varying_double(<4 x double>) nounwind readonly alwaysinline {
  %call = call <4 x double> @__rcp_fast_varying_double(<4 x double> %0)
  ;; do one Newton-Raphson iteration to improve precision
  ;;  double iv = __rcp_v(v);
  ;;  return iv * (2. - v * iv);
  %v_iv = fmul <4 x double> %0, %call
  %two_minus = fsub <4 x double> <double 2., double 2., double 2., double 2.>, %v_iv
  %iv_mul = fmul <4 x double> %call,  %two_minus
  ret <4 x double> %iv_mul
}

rsqrt14_uniform()
;; rsqrt float
declare <4 x float> @llvm.x86.avx512.rsqrt14.ps.128(<4 x float>,  <4 x float>,  i8) nounwind readnone
define <4 x float> @__rsqrt_fast_varying_float(<4 x float> %v) nounwind readonly alwaysinline {
  %ret = call <4 x float> @llvm.x86.avx512.rsqrt14.ps.128(<4 x float> %v,  <4 x float> undef,  i8 -1)
  ret <4 x float> %ret
}
define <4 x float> @__rsqrt_varying_float(<4 x float> %v) nounwind readonly alwaysinline {
  %is = call <4 x float> @__rsqrt_fast_varying_float(<4 x float> %v)
  ; Newton-Raphson iteration to improve precision
  ;  float is = __rsqrt_v(v);
  ;  return 0.5 * is * (3. - (v * is) * is);
  %v_is = fmul <4 x float> %v,  %is
  %v_is_is = fmul <4 x float> %v_is,  %is
  %three_sub = fsub <4 x float> <float 3., float 3., float 3., float 3.>, %v_is_is
  %is_mul = fmul <4 x float> %is,  %three_sub
  %half_scale = fmul <4 x float> <float 0.5, float 0.5, float 0.5, float 0.5>, %is_mul
  ret <4 x float> %half_scale
}

;; rsqrt double
declare <4 x double> @llvm.x86.avx512.rsqrt14.pd.256(<4 x double>,  <4 x double>,  i8) nounwind readnone
define <4 x double> @__rsqrt_fast_varying_double(<4 x double> %val) nounwind readonly alwaysinline {
  %res = call <4 x double> @llvm.x86.avx512.rsqrt14.pd.256(<4 x double> %val, <4 x double> undef, i8 -1)
  ret <4 x double> %res
}
declare <4 x i1> @llvm.x86.avx512.fpclass.pd.256(<4 x double>, i32)
define <4 x double> @__rsqrt_varying_double(<4 x double> %v) nounwind readonly alwaysinline {
  %corner_cases = call <4 x i1> @llvm.x86.avx512.fpclass.pd.256(<4 x double> %v, i32 14)
  %is = call <4 x double> @__rsqrt_fast_varying_double(<4 x double> %v)

  ; Precision refinement sequence based on minimax approximation.
  ; This sequence is a little slower than Newton-Raphson, but has much better precision
  ; Relative error is around 3 ULPs.
  ; t1 = 1.0 - (v * is) * is
  ; t2 = 0.37500000407453632 + t1 * 0.31250000550062401
  ; t3 = 0.5 + t1 * t2
  ; t4 = is + (t1*is) * t3
  %v_is = fmul <4 x double> %v,  %is
  %v_is_is = fmul <4 x double> %v_is,  %is
  %t1 = fsub <4 x double> <double 1., double 1., double 1., double 1.>, %v_is_is
  %t1_03125 = fmul <4 x double> <double 0.31250000550062401, double 0.31250000550062401, double 0.31250000550062401, double 0.31250000550062401>, %t1
  %t2 = fadd <4 x double> <double 0.37500000407453632, double 0.37500000407453632, double 0.37500000407453632, double 0.37500000407453632>, %t1_03125
  %t1_t2 = fmul <4 x double> %t1, %t2
  %t3 = fadd <4 x double> <double 0.5, double 0.5, double 0.5, double 0.5>, %t1_t2
  %t1_is = fmul <4 x double> %t1, %is
  %t1_is_t3 = fmul <4 x double> %t1_is, %t3
  %t4 = fadd <4 x double> %is, %t1_is_t3
  %ret = select <4 x i1> %corner_cases, <4 x double> %is, <4 x double> %t4
  ret <4 x double> %ret
}

;;saturation_arithmetic_novec()

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dot product
