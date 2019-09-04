FUNCTION READ_TMI_AVERAGED_HDF, filename, $
				PARAMETERS=parameters, $
				NO_LAND   =no_land, $
				LIMIT     =limit

;+
; Name:READ_TMI_AVERAGED_HDF_V1
;		READ_TMI_DAY_HDF_V1
; Purpose:
; 	This prcedure will read monthly TMI HDF files. 
;		Created from the TMI daily bytemap files (version-4 released September 2006).
; Calling Sequence
;		data = READ_TMI_AVERAGED_HDF_V1(filename)
; Inputs:
;   	filename :  Name of file to read complete with path
;   				filenames have form TMI_yyyymmv4.HDF
;   				where yyyy     = year
;       			mm      = month
;
; Outputs:
;		sst, w11, w37, vapor, cloud, rain real arrays sized (1440,320,days_in_month)
;   sst   : the sea surface temperature in degree Celcius, valid range=[-3.0,34.5]
;		w11   : the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  from 11 GHz channel
;		w37   : the 10 meter surface wind speed in meters/second,  valid range=[0.,50.]  from 37 GHz channel
;		vapor : the columnar atmospheric water vapor in millimeters,  valid range=[0.,75.]
;		cloud : the liquid cloud water in millimeters, valid range = [0.,2.5]
;		rain  : the derived radiometer rain rate in millimeters/hour,  valid range = [0.,25.]
; Keywords:
;		PARAMETERS	: String array of parameters needed from file.
;		NO_LAND			: Set to make points over land NaN characters.
;									Default is to store as 255.
; Author and History:
;		Kyle R. Wodzicki	Created 21 July 2014
;			MODIFIED 24 July 2014
;
;				Add PARAMETERS keyword to only read in and return user specified
;				parameters.
;			MODIFIED 13 Aug. 2014:
;				Added NO_LAND keyword and changed the handeling of the 
;				PARAMETERS KEYWORD.
;     MODIFIED 01 Dec. 2014 by Kyle R. Wodzicki
;       Added limit keyword.
;
; NOTE:
;		Longitude  is 0.25*(xdim+1)- 0.125     !IDL is zero based    East longitude
;		Latitude   is 0.25*(ydim+1)-40.125
;		Or, the GRID_POINTS function can be used to return the lat/long values needed
;		by using the keyword /TMI, eg. grid = GRID_POINTS(/TMI). This will return
;		a structure where grid.LAT gives latitude points and grid.LON gives longitude.
;-

COMPILE_OPT IDL2																											;Set compile options


sds_file_ID = HDF_SD_START(filename, /READ)														;Start the HDF file for SD data set reading
HDF_SD_FILEINFO, sds_file_ID, numsds, numatt													;Get information about the SD data set
IF (N_ELEMENTS(parameters) EQ 0) THEN BEGIN
	parameters = ['SST', 'W11', 'W37', 'VAPOR', $												;All parameter names
								'CLOUD', 'RAIN', 'LON', 'LAT']
ENDIF ELSE parameters = STRUPCASE(parameters)

IF (N_ELEMENTS(limit) NE 0) THEN BEGIN
  FOR i = 0, numsds-1 DO BEGIN
    sds_ID	= HDF_SD_SELECT(sds_file_ID, i)														;Select the ith variable for reading
	    HDF_SD_GETINFO, sds_ID, NAME=name													  		;Get the name of the data
	    IF STRMATCH('LAT', name, /FOLD_CASE) THEN BEGIN
	      HDF_SD_GETDATA, sds_id, lat
	      lat_id = WHERE(lat GE limit[0] AND lat LE limit[2], lat_CNT)
	    ENDIF
	    IF STRMATCH('LON', name, /FOLD_CASE) THEN BEGIN
	      HDF_SD_GETDATA, sds_id, lon
	      lon_id = WHERE(lon GE limit[1] AND lon LE limit[3], lon_CNT)
	    ENDIF
	  HDF_SD_ENDACCESS,sds_ID																							;End access to variable
  ENDFOR
ENDIF ELSE BEGIN
  lat_CNT = 0 & lon_CNT = 0
ENDELSE

outData	= {}																													;Initialize outData as empty STRUCT

FOR i = 0, numsds-1 DO BEGIN																					;Iterate over all data in the SD data set
	sds_ID	= HDF_SD_SELECT(sds_file_ID, i)															;Select the ith variable for reading
	  HDF_SD_GETINFO, sds_ID, NAME=name																	;Get the name of the data
    name = STRUPCASE(name)
    IF TOTAL(STRMATCH(parameters, name)) EQ 1 THEN BEGIN              ;If the SD data matches a user requested parameter
      HDF_SD_GETDATA, sds_ID, data																	  ;Get data from the variable
      IF KEYWORD_SET(no_land) AND (name NE 'LON') THEN BEGIN  ;If NO_LAND set, convert to NaN
        id = WHERE(data EQ 255, CNT)
        IF (CNT NE 0) THEN data[id] = !VALUES.F_NaN
      ENDIF
			IF (name EQ 'LAT') THEN BEGIN
				IF (lat_CNT GT 0) THEN data = data[lat_id]
				outData = CREATE_STRUCT(outData, 'LAT', data)										;Write data to out variable
			ENDIF ELSE IF (name EQ 'LON') THEN BEGIN
				IF (lon_CNT GT 0) THEN data = data[lon_id]
				outData = CREATE_STRUCT(outData, 'LON', data)										;Write data to out variable
			ENDIF ELSE BEGIN
        IF (lon_CNT GT 0) THEN data = data[lon_id, *, *]
        IF (lat_CNT GT 0) THEN data = data[*, lat_id, *]
        outData = CREATE_STRUCT(outData, name, data)										;Write data to out variable
      ENDELSE
	  ENDIF
	HDF_SD_ENDACCESS,sds_ID																							;End access to variable
ENDFOR																																;END i

HDF_SD_END, sds_file_ID

RETURN, outData																												;Return the data structure

END
