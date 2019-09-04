FUNCTION READ_TMI_DAY_HDF, filename

;+
; Name:
;		READ_TMI_DAY_HDF_V1
; Purpose:
; 		This prcedure will read the pentad averaged TMI monthly HDF files 
;		created from the TMI daily bytemap files (version-4 released September 2006).
; Calling Sequence
;		READ_TMI_DAY_HDF_V1, filename, time, sst, w11, w37, vapor, cloud, rain
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
;		None.
; Author and History:
;		Kyle R. Wodzicki	Created 27 June 2014
;	Modified to read in both 
; NOTE:
;		Longitude  is 0.25*(xdim+1)- 0.125     !IDL is zero based    East longitude
;		Latitude   is 0.25*(ydim+1)-40.125
;		Or, the GRID_POINTS function can be used to return the lat/long values needed
;		by using the keyword /TMI, eg. grid = GRID_POINTS(/TMI). This will return
;		a structure where grid.LAT gives latitude points and grid.LON gives longitude.
;-

COMPILE_OPT IDL2											;Set compile options

; Data is stored as INT to reduces file size, multipliers to change binary data to real data
scale		= [0.15, 0.2, 0.2, 0.3, 0.01, 0.1]
offset	= [-3.0, 0.0, 0.0, 0.0, 0.0, 0.0]

outData	= {}																													;Initialize outData as empty STRUCT

sds_file_ID = HDF_SD_START(filename, /READ)														;Start the HDF file for SD data set reading
HDF_SD_FILEINFO, sds_file_ID, numsds, numatt													;Get information about the SD data set

FOR i = 0, numsds-1 DO BEGIN																					;Iterate over all data in the SD data set
	sds_ID	= HDF_SD_SELECT(sds_file_ID, i)															;Select the ith variable for reading
	HDF_SD_GETINFO, sds_ID, NAME=name																		;Get the name of the data
	
	HDF_SD_GETDATA, sds_ID, data																				;Get data from the variable
	HDF_SD_ENDACCESS,sds_ID																							;End access to variable
	
	name = STRUPCASE(name)																							;Convert the name to upper case
	CASE name OF
		'SST'				: outData=CREATE_STRUCT(outData,name,data*scale[0]+offset[0])	;Convert to real data
		'W11'				: outData=CREATE_STRUCT(outData,name,data*scale[1]+offset[1])
		'W37'				: outData=CREATE_STRUCT(outData,name,data*scale[2]+offset[2])
		'VAPOR'			: outData=CREATE_STRUCT(outData,name,data*scale[3]+offset[3])
		'CLOUD'			: outData=CREATE_STRUCT(outData,name,data*scale[4]+offset[4])
		'RAINRATE'	: outData=CREATE_STRUCT(outData,name,data*scale[5]+offset[5])
		ELSE				: MESSAGE, 'Error on read. No data present.'
	ENDCASE
ENDFOR

HDF_SD_END, sds_file_ID

RETURN, outData																												;Return the data structure

END
