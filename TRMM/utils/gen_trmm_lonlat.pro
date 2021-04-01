PRO GEN_TRMM_LONLAT, product, lon, lat
;+
; Name:
;   GEN_TRMM_LONLAT
; Purpose:
;   Procedure to generate longitude and latitude values for a given TRMM
;   data product.
; Inputs:
;   product (string) : The data product to generate longiutde/latiude 
;     values for.
; Outputs:
;   lon (array) : Named variable containing longitude values upon return
;   lat (array) : Named variable containing latitude values upon return
; Keywords:
;   None.
;-

COMPILE_OPT IDL2

prod = STRUPCASE(product)
IF prod EQ '3B31' THEN BEGIN
  nLon =  720
  dLon =    0.5
  oLon = -180

  nLat =  160
  dLat =    0.5
  oLat =  -40
ENDIF ELSE $
  MESSAGE, 'Unsupported TRMM product: ' + prod

lon = INDGEN(nLon) * dLon + (oLon + dLon/2.0)
lat = INDGEN(nLat) * dLat + (oLat + dLat/2.0)

END
