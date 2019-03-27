FUNCTION READ_TMI_RUN_MEAN_V1, filename, $
					PARAMETERS=parameters, $
					NO_GOM		=no_gom, $
					LIMITS		=limits, $
					RRDAY			=rrday

;+
; Name:
;		READ_TMI_RUN_MEAN_V1
; Purpose:
;   A function to read in running mean data created by the 
;   CREATE_TMI_RUNNING_MEANS procedure.
; Inputs:
;   filename   : File name of running mean data. In the format
;                tmi_YYYYMMv4.HDF
; Outputs:
;   Returns a structure containing all, or some, of the data
;   in the running mean file.
; Keywords:
;   PARAMETERS : A string or string array containing the names
;                of the variables to read in.
;   NO_GOM     : Set to remove the Gulf of Mexico from the data
;   LIMITS     : Set to [south, west, north, east] boundaries
;                of data to read in.
;   RRDAY      : Set to convert the rain rate FROM mm/hr TO mm/day
; Author and History:
;   Kyle R. Wodzicki    Created 3 Oct. 2014
;
; Basis of program based off of routines from remss.com
;
; The routine returns:
;   sst, w11, w37, vapor, cloud, rain real arrays sized (1440,320)
;   sst   is the sea surface temperature in degree Celcius, 
;					valid range=[-3.0,34.5]
;   w11  is the 10 meter surface wind speed in meters/second,  
;					valid range=[0.,50.]  derived using the 11 GHz channel
;   w37  is the 10 meter surface wind speed in meters/second,  
;					valid range=[0.,50.]  derived using the 37 GHz channel
;   vapor is the columnar atmospheric water vapor in millimeters,  
;					valid range=[0.,75.]
;   cloud is the liquid cloud water in millimeters, 
;					valid range = [0.,2.5]
;   rain  is the derived radiometer rain rate in millimeters/hour,  
;					valid range = [0.,25.]
;
; Longitude  is 0.25*(xdim+1)-0.125   !IDL is zero based East longitude
; Latitude   is 0.25*(ydim+1)-40.125
;
;
; please read the description file on www.remss.com
; for infomation on the various fields, or contact
; support@remss.com with questions about the data.
;-

COMPILE_OPT IDL2

;Determine if file exists
exist = FINDFILE(filename,COUNT=cnt)
IF (cnt NE 1) THEN $
	MESSAGE, 'FILE DOES NOT EXIST or MORE THAN ONE FILE EXISTS!!'

var_names   = ['SST_MEAN',   'SST_STDDEV',   $
               'W11_MEAN',   'W11_STDDEV',   $
               'W37_MEAN',   'W37_STDDEV',   $
               'VAPOR_MEAN', 'VAPOR_STDDEV', $
               'CLOUD_MEAN', 'CLOUD_STDDEV', $
               'RR_MEAN',    'RR_STDDEV']
no_flt_vars = ['NUM_FILES', 'YEAR', 'MONTH', 'DAY']                   ;Vars to skip filtering
no_flt_data = {}                                                      ;Initialize data that does not get filtered
out_data    = {}                                                      ;Initialize out_data Struct

;=====================================================================
;Create latitude and longitude and shift
nLon = 1440
nLat = 320

lon = 0.25*(FINDGEN(nLon)+1) - 00.125
lat = 0.25*(FINDGEN(nLat)+1) - 40.125

IF KEYWORD_SET(limits) THEN BEGIN
  limits[1] = (limits[1] LT 0) ? limits[1]+360.0 : limits[1]          ;Convert to 360 degree not -180 to 180
  limits[3] = (limits[3] LT 0) ? limits[3]+360.0 : limits[3]          ;Convert to 360 degree not -180 to 180
	IF (limits[1] GT limits[3]) THEN BEGIN                              ;If crossing International date line
		lon_id = WHERE(lon GE limits[1] OR lon LE limits[3],lon_CNT)
	ENDIF ELSE BEGIN
		lon_id = WHERE(lon GE limits[1] AND lon LE limits[3],lon_CNT)
	ENDELSE
	lat_id = WHERE(lat GE limits[0] AND lat LE limits[2],lat_CNT)

  lat = (lat_CNT NE 0 AND lat_CNT NE nLat) ? lat[lat_id] : lat	
	lon = (lon_CNT NE 0 AND lon_CNT NE nLon) ? lon[lon_id] : lon
ENDIF ELSE BEGIN
	lon_CNT = 0 
	lat_CNT = 0
ENDELSE

IF KEYWORD_SET(no_gom) THEN BEGIN                                     ;Land ocean mask 
  GoM = CREATE_PACIFIC_OCEAN_MASK(/tmi)
  GoM = WHERE(ocean EQ 1, GoM_CNT)
ENDIF ELSE GoM_CNT = 0

sds_file_ID = HDF_SD_START(filename, /READ)                           ;Start the HDF file for SD data set reading
  HDF_SD_FILEINFO, sds_file_ID, numsds, numatt                        ;Get information about the SD data set

  FOR i = 0, numsds-1 DO BEGIN                                        ;Iterate over all data in the SD data set
    sds_ID	= HDF_SD_SELECT(sds_file_ID, i)                           ;Select the ith variable for reading
      HDF_SD_GETINFO, sds_ID, NAME=name                               ;Get the name of the data
      
      flt_chck = TOTAL(STRMATCH(no_flt_vars, name, /FOLD_CASE))       ;See if the variable matches the no filter var
      
      IF KEYWORD_SET(parameters) THEN $                               ;If key set
        chck = WHERE(STRMATCH(parameters, name, /FOLD_CASE),CNT)      ;  Check if name is in vars requested
      
      IF (CNT  EQ 0     OR $
          name EQ 'LON' OR $
          name EQ 'LAT' AND $
          flt_chck EQ 0) THEN GOTO, SKIP_DATA                         ;If not found, or lat or lon, then skip to next name
      
      HDF_SD_GETDATA, sds_ID, data                                    ;Get data from the variable
      
      IF KEYWORD_SET(RRDAY) AND name EQ 'RR_MEAN' THEN data=data*24   ;Convert to mm/day
      
      IF flt_chck THEN BEGIN                                          ;Add data to no filter structure
        no_flt_data = CREATE_STRUCT(no_flt_data, name, data)
        GOTO, SKIP_DATA
      ENDIF ELSE BEGIN       
				IF (GoM_CNT NE 0) THEN data[GoM] = !VALUES.F_NaN              ;Replace GOM
				IF (lat_CNT NE 0 AND lat_cnt NE nLat) THEN $                  ;Filter data by latitude
				    data = data[*,lat_id,*]
				IF (lon_CNT NE 0 AND lon_cnt NE nLat) THEN $                  ;Filter data by longitude
					  data = data[lon_id,*,*]
		  ENDELSE
		
			IF KEYWORD_SET(parameters) THEN BEGIN
				FOR var = 0, N_ELEMENTS(parameters)-1 DO BEGIN                ;Iterate over parameters
				  var_id = WHERE(STRMATCH(var_names, parameters[var], $
				                           /FOLD_CASE), var_CNT)
				  IF (var_CNT EQ 1) THEN $
				    out_data=CREATE_STRUCT(out_data,var_names[var_id],data)       
			  ENDFOR                                                        ;END var
			ENDIF ELSE out_data = CREATE_STRUCT(out_data, name, data)       ;Else, just add data
		  
		  SKIP_DATA: ;Jump here
    HDF_SD_ENDACCESS,sds_ID                                           ;End access to variable
  ENDFOR                                                              ;END i
HDF_SD_END, sds_file_ID                                               ;Close the HDF file

dims = [N_ELEMENTS(lon), N_ELEMENTS(lat)]
lon = REBIN(lon, dims)                                                ;Rebin to 1440 X 320 array
lat = REBIN(TRANSPOSE(lat),dims)                                      ;Rebin to 1440 X 320 array

out_data = CREATE_STRUCT(out_data, 'LAT', lat, 'LON', lon, $          ;Append on filter data, lat, and lon
                         no_flt_data)
RETURN, out_data
END