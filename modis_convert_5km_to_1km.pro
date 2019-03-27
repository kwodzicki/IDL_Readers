FUNCTION GET_Y_POS_5KM_TO_1KM, isc_5km, itk_p1_5km, itk_p2_5km, lat_5km, lon_5km, itk_1km
COMPILE_OPT IDL2, HIDDEN
p1_5km_lat = lat_5km [ isc_5km, itk_p1_5km ]
p1_5km_lon = lon_5km [ isc_5km, itk_p1_5km ]
p2_5km_lat = lat_5km [ isc_5km, itk_p2_5km ]
p2_5km_lon = lon_5km [ isc_5km, itk_p2_5km ]

id = WHERE( ABS(p1_5km_lon - p2_5km_lon) GT 180, CNT)
IF CNT GT 0 THEN BEGIN
  id1 = WHERE(p1_5km_lon[id] LT 0, CNT)
  IF CNT GT 0 THEN p1_5km_lon[id[id1]] += 360
  id1 = WHERE(p2_5km_lon[id] LT 0, CNT)
  IF CNT GT 0 THEN p2_5km_lon[id[id1]] += 360
ENDIF
itk_p1_1km = 2.0 + 5.0 * itk_p1_5km
itk_p2_1km = 2.0 + 5.0 * itk_p2_5km
alpha_lon = ( p2_5km_lon - p1_5km_lon ) / ( itk_p2_1km - itk_p1_1km )
alpha_lat = ( p2_5km_lat - p1_5km_lat ) / ( itk_p2_1km - itk_p1_1km )
lon = p1_5km_lon + alpha_lon * ( itk_1km - itk_p1_1km )
lat = p1_5km_lat + alpha_lat * ( itk_1km - itk_p1_1km )

id = WHERE(lon GT 180, CNT)
IF CNT GT 0 THEN lon[id] -= 360
id = WHERE(lon LT -180, CNT)
IF CNT GT 0 THEN lon[id] += 360

RETURN, {lon : lon, lat : lat}
END

FUNCTION GET_X_POS_5KM_TO_1KM, lat_left_1km,  lon_left_1km,  isc_left_5km, lat_right_1km, lon_right_1km, isc_right_5km, isc_1km
COMPILE_OPT IDL2, HIDDEN
isc_left_1km  = 2. + 5. * isc_left_5km
isc_right_1km = 2. + 5. * isc_right_5km

;print "isc_left_5km=%d isc_right_5km=%d"%(isc_left_5km, isc_right_5km)
;print "isc_left_1km=%d isc_right_1km=%d"%(isc_left_1km, isc_right_1km)
;print "isc_1km_min=%d isc_1km_max=%d"%(isc_1km_min,isc_1km_max)

; linear interpolation on the position
alpha_lon = ( lon_right_1km - lon_left_1km ) / ( isc_right_1km - isc_left_1km )
alpha_lat = ( lat_right_1km - lat_left_1km ) / ( isc_right_1km - isc_left_1km )

lat = lat_left_1km + alpha_lat * ( isc_1km - isc_left_1km )
lon = lon_left_1km + alpha_lon * ( isc_1km - isc_left_1km )

RETURN, {lon : lon, lat : lat}
END

FUNCTION MODIS_CONVERT_5KM_TO_1KM, lon_5km, lat_5km, DIMS = dims
;+
; Name:
;   MODIS_CONVERT_5KM_TO_1KM 
; Purpose:
;   An IDL function to convert MODIS longitude/latitude data at 5km resolution
;   to 1km resolution.
; Inputs:
;   lon    : Array of longitude values
;   lat    : Array of latitude values
; Outputs:
;   Returns longitude and latitude value arrays at 1km resolution
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 19 Mar. 2018
;
; Adapted from http://www.icare.univ-lille1.fr/tutorials/MODIS_geolocation
;-
COMPILE_OPT IDL2

IF N_ELEMENTS(dims) EQ 0 THEN dims = SIZE(lon_5km, /DIMENSIONS) * 5

sz_sc_1km = dims[0]  ; Number of points at 1km resolution across-track
sz_tk_1km = dims[1]  ; Number of points at 1km resolution along-track

isc_1km = REBIN(LINDGEN(sz_sc_1km), dims)       ; Indices for across-track
itk_1km = REBIN(LINDGEN(1, sz_tk_1km), dims)    ; Indices for along-track

isc_5km = ( isc_1km - 2.0 ) / 5.0
itk_5km = ( itk_1km - 2.0 ) / 5.0

n = 10
itk_top_5km    = FLOOR(itk_5km)
itk_bottom_5km = itk_top_5km + 1

id = WHERE( (itk_1km MOD n) LE 2, CNT)
IF CNT GT 0 THEN BEGIN
  itk_top_5km[id]    = CEIL(itk_5km[id])
  itk_bottom_5km[id] = itk_top_5km[id] + 1
ENDIF
id = WHERE( (itk_1km MOD n) GE 7, CNT)
IF CNT GT 0 THEN itk_bottom_5km[id] = itk_top_5km[id] - 2

isc_left_5km  = FLOOR(isc_5km)
isc_right_5km = isc_left_5km + 1
id = WHERE(isc_1km LE 2, CNT)
IF CNT GT 0 THEN BEGIN
  isc_left_5km[id]  = 0
  isc_right_5km[id] = 1
ENDIF
id = WHERE(isc_5km GE (dims[0]-1), CNT)
IF CNT GT 0 THEN BEGIN
	isc_left_5km[id]  = dims[0] - 2
	isc_right_5km[id] = dims[0] - 1
ENDIF

; --- set the 5km track lines position ; left border ---
left_1km = GET_Y_POS_5KM_TO_1KM( $
                 isc_left_5km, itk_top_5km, itk_bottom_5km, $
                 lat_5km, lon_5km, $
                 itk_1km )
; --- set the 5km track lines position ; right border ---
right_1km = GET_Y_POS_5KM_TO_1KM( $
                 isc_right_5km, itk_top_5km, itk_bottom_5km, $
                 lat_5km, lon_5km, $
                 itk_1km )

RETURN, GET_X_POS_5KM_TO_1KM( left_1km.LAT,  left_1km.LON,  isc_left_5km, $
                              right_1km.LAT, right_1km.LON, isc_right_5km, $
                              isc_1km )
;RETURN, -1
END