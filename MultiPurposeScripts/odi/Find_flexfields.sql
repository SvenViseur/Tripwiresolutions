SELECT trt.trt_name procedure, val.ff_code flex_field, val.short_txt_value value
  FROM CIVL4_ODI_REPO.snp_trt trt
  JOIN civl4_odi_repo.snp_ff_valuew val On (trt.i_trt = val.i_instance)
--  JOIN civl4_odi_repo.snp_flex_field flx ON (val.i_objects = flx.i_objects)
 WHERE trt.i_trt = 1158;