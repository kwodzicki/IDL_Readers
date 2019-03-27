FUNCTION READ_VIIRS_FILE, file
;+
; Name:
;   READ_VIIRS_FILE
; Purpose:
;   A function to read in a VIIRS file containing:
;     latitude, longitude, brightness temp channel 14, channel 15, channel 16
; Inputs:
;   file   : Full path to the file to read
; Outputs:
;   Returns a structure containing all the data.
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 11 May 2016.
;-
COMPILE_OPT IDL2

IF (N_PARAMS() NE 1) THEN MESSAGE, 'Incorrect number of inputs!'                ; Print message if file not input

;=== Get the number of lines in the file
SPAWN, 'cat '+file + ' | wc -l', result
nLines = LONG(result)

all_lat = FLTARR(nLines)                                                        ; Initialize float array to store all latitudes in
all_lon = FLTARR(nLines)                                                        ; Initialize float array to store all longitude in
all_c14 = FLTARR(nLines)                                                        ; Initialize float array to store all channel 14 data in
all_c15 = FLTARR(nLines)                                                        ; Initialize float array to store all channel 15 data in
all_c16 = FLTARR(nLines)                                                        ; Initialize float array to store all channel 16 data in

lat = 0.0 & lon = 0.0 & c14 = 0.0 & c15 = 0.0 & c16 = 0.0                       ; Initialize variables for reading in the data
i = 0LL                                                                         ; Initialize line counter

OPENR, iunit, file, /GET_LUN                                                    ; Open the file for reading
WHILE NOT EOF(iunit) DO BEGIN                                                   ; Iterate until the end of the file
	READF, iunit, lat, lon, c14, c15, c16, FORMAT="(F12.9, F13.8, 3F12.8)"        ; Read in a line
	all_lat[i] = lat                                                              ; Place latitude value into array
	all_lon[i] = lon                                                              ; Place longitude value into array
	all_c14[i] = c14                                                              ; Place channel 14 value into array
  all_c15[i] = c15                                                              ; Place channel 15 value into array
  all_c16[i] = c16                                                              ; Place channel 16 value into array
	i++
ENDWHILE
FREE_LUN, iunit                                                                 ; Close the file

RETURN, {LAT : all_lat, $                                                       ; Return the data
         LON : all_lon, $
         C14 : all_C14, $
         C15 : all_C15, $
         C16 : all_C16}
END