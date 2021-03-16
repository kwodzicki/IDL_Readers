FUNCTION READ_ALL_GPCP, version, $
  LONG_OUT = long_out, $
  LAT_OUT  = lat_out, $
  _EXTRA   = _extra

;+
; Name:
;   READ_ALL_GPCP
; Purpose:
;   A function to read in all GPCP netCDF files and place data into single
;   3D array.
; Inputs:
;   version : (Optional) The GPCP data version; default is 2.3
; Keywords:
;   LONG_OUT : Longitude values to interpolate to for output.
;   LAT_OUT  : Latitude values to interpolate to for output.
; Returns:
;   Structure containing data.
; Notes:
;   Bilinear interpolation is performed if both long_out and lat_out are
;   set. If only one is set, then linear interpolation is used.
;-

COMPILE_OPT IDL2

IF N_ELEMENTS(version) EQ 0 THEN version = 2.3
vars   = ['precip', 'longitude', 'latitude']
files  = GPCP_FILEPATH(version=version, COUNT=nFiles, _EXTRA=_extra)
precip = LIST()
time   = DBLARR(nFiles, /NoZero)
FOR i = 0, nFiles-1 DO BEGIN
  data = READ_netCDF_FILE(files[i], VARIABLES=vars)
  precip.ADD, data.VARIABLES.PRECIP.VALUES
  time[i] = data.VARIABLES.TIME.JULDAY
ENDFOR

precip    = precip.ToArray(/Transpose, /No_Copy)
longitude = data.VARIABLES.LONGITUDE.VALUES
latitude  = data.VARIABLES.LATITUDE.VALUES

IF N_ELEMENTS(long_out) NE 0 OR N_ELEMENTS(lat_out) NE 0 THEN BEGIN
  lonID  = FINDGEN(longitude.LENGTH)
  latID  = FINDGEN(latitude.LENGTH )
  timeID = INDGEN(nFiles)
  IF N_ELEMENTS(long_out) NE 0 THEN $
    lonID = INTERPOL(lonID, longitude, long_out) 
  IF N_ELEMENTS(lat_out) NE 0 THEN $
    latID = INTERPOL(latID, latitude, lat_out) 

  precip = INTERPOLATE(precip, lonid, latid, timeid, /GRID)
ENDIF

RETURN, {LONGITUDE : longitude, $
         LATITUDE  : latitude, $ 
         TIME      : time, $
         PRECIP    : precip} 

END
