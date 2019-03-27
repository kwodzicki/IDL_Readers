FUNCTION READ_COMBINED_BINARY, FILENUM=filenum, DATE=date, FILENAME=filename

;+
; Name:
;   READ_COMBINED_BINARY2
; Purpose:
;   To read one combined file (AMSR-E, CloudSat, MODIS, etc. data combined) in binary format created with combine_binary2.pro 
; Calling Sequence:
;   data = read_combined_binary2(FILENUM=filenum, DATE=date, FILENAME=filename)
; Inputs:
;   none
; Outputs:
;   none
; Keywords:
;   FILENUM   : Optional. File list index number to be read. Ex: FILENUM=0 reads the first file found in the search of the directory.
;   DATE      : Optional. The program will use this date and find the combined file that contains the data from this date.
;               Note: Reads the entire file, not the singular date.
;   FILENAME  : Optional. Provide the filename of the desired file.             
; Author and History:
;   Tony Viramontez         Created 9 October 2015
;
;-

COMPILE_OPT IDL2

IF n_elements(filenum) EQ 0 THEN filenum=0

cd, '/Volumes/ATRAIN/COMBINE'

x = file_search('*.dat')

IF n_elements(date) GT 0 THEN BEGIN
  start_yr  = strmid(x, 0, 4)
  start_mon = strmid(x, 4, 2)
  start_day = strmid(x, 6, 2)

  end_yr  = strmid(x, 12, 4)
  end_mon = strmid(x, 16, 2)
  end_day = strmid(x, 18, 2)

  year = strmid(date, 0, 4)
  month= strmid(date, 5, 2)
  day  = strmid(date, 8, 2)

  day_of_year   = JULDAY(month,day,year) - JULDAY(1,1,year) + 1
  start_day_year= JULDAY(start_mon,start_day,start_yr) - JULDAY(1,1,start_yr) + 1
  end_day_year  = JULDAY(end_mon,end_day,end_yr) - JULDAY(1,1,end_yr) + 1

  difference = start_day_year - day_of_year

  neg = difference < 0
  neg[WHERE(neg EQ 0, /NULL)] = -1000    ; Set values of 0 to -1000
  closest = MAX(neg, max_ind)

  FILENAME = x[max_ind]

  infile = strmid(filename, 0, strlen(filename) - 4) + '.txt'
    
  n = FILE_LINES(infile)
    
  OPENR, iunit, infile, /GET_LUN
    
  vars  = strarr(n)
  types = strarr(n)
  n_dims= strarr(n)
  x_dims= strarr(n)
  y_dims= strarr(n)
  z_dims= strarr(n)
  t_dims= strarr(n)
    
  line = ''
  header = list()
       
  FOR k = 0, n-1 DO BEGIN
    READF, iunit, line, ' '
    header.add,  STRSPLIT(STRING(line), ' ', /EXTRACT) 
  ENDFOR
    
  FREE_LUN, iunit
  
  OPENR, ounit, FILENAME, /GET_LUN
    
  names = header[0]
  data = []
  struct = {}

  FOR i = 0, n_elements(header[0]) - 1 DO BEGIN  
     FOR j = 1, n_elements(header) - 1 DO BEGIN          
        data = [data, header[j, i]]
     ENDFOR
       
     struct = create_struct(struct, names[i], data)
     data = []
  ENDFOR
    
  data = {}

  FOR i = 0 , n_elements(STRUCT.VARIABLES) - 1 DO BEGIN

    x = float(struct.X_DIM[i])
    y = float(struct.Y_DIM[i])
    z = float(struct.Z_DIM[i])
    t = float(struct.T_DIM[i])

    IF struct.TYPE[i] EQ 'F' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = fltarr(x)
        '2' : var = fltarr(x,y)
        '3' : var = fltarr(x,y,z)
        '4' : var = fltarr(x,y,z,t)
      ENDCASE
    ENDIF

    IF struct.TYPE[i] EQ 'I' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = intarr(x)
        '2' : var = intarr(x,y)
        '3' : var = intarr(x,y,z)
        '4' : var = intarr(x,y,z,t)
      ENDCASE
    ENDIF

    IF struct.TYPE[i] EQ 'L' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = lonarr(x)
        '2' : var = lonarr(x,y)
        '3' : var = lonarr(x,y,z)
        '4' : var = lonarr(x,y,z,t)
      ENDCASE
    ENDIF

    IF struct.TYPE[i] EQ 'B' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = bytarr(x)
        '2' : var = bytarr(x,y)
        '3' : var = bytarr(x,y,z)
        '4' : var = bytarr(x,y,z,t)
      ENDCASE
    ENDIF
           
    READU, ounit, var

    name = STRUCT.VARIABLES[i]
    DATA = CREATE_STRUCT(DATA, name, var)
  ENDFOR

  FREE_LUN, ounit


ENDIF ELSE BEGIN

  IF n_elements(FILENAME) EQ 0 THEN FILENAME = x[filenum]

  infile = strmid(filename, 0, strlen(filename) - 4) + '.txt'
    
  n = FILE_LINES(infile)
    
  OPENR, iunit, infile, /GET_LUN
    
  vars  = strarr(n)
  types = strarr(n)
  n_dims= strarr(n)
  x_dims= strarr(n)
  y_dims= strarr(n)
  z_dims= strarr(n)
  t_dims= strarr(n)
    
  line = ''
  header = list()
       
  FOR k = 0, n-1 DO BEGIN
    READF, iunit, line, ' '
    header.add,  STRSPLIT(STRING(line), ' ', /EXTRACT) 
  ENDFOR
    
  FREE_LUN, iunit
    
  OPENR, ounit, FILENAME, /GET_LUN
    
  names = header[0]
  data = []
  struct = {}

  FOR i = 0, n_elements(header[0]) - 1 DO BEGIN  
     FOR j = 1, n_elements(header) - 1 DO BEGIN          
        data = [data, header[j, i]]
     ENDFOR
       
     struct = create_struct(struct, names[i], data)
     data = []
  ENDFOR
    
  data = {}

  FOR i = 0 , n_elements(STRUCT.VARIABLES) - 1 DO BEGIN

    x = float(struct.X_DIM[i])
    y = float(struct.Y_DIM[i])
    z = float(struct.Z_DIM[i])
    t = float(struct.T_DIM[i])

    IF struct.TYPE[i] EQ 'F' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = fltarr(x)
        '2' : var = fltarr(x,y)
        '3' : var = fltarr(x,y,z)
        '4' : var = fltarr(x,y,z,t)
      ENDCASE
    ENDIF


    IF struct.TYPE[i] EQ 'I' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = intarr(x)
        '2' : var = intarr(x,y)
        '3' : var = intarr(x,y,z)
        '4' : var = intarr(x,y,z,t)
      ENDCASE
    ENDIF

    IF struct.TYPE[i] EQ 'L' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = lonarr(x)
        '2' : var = lonarr(x,y)
        '3' : var = lonarr(x,y,z)
        '4' : var = lonarr(x,y,z,t)
      ENDCASE
    ENDIF

    IF struct.TYPE[i] EQ 'B' THEN BEGIN
      CASE struct.N_DIM[i] of
        '1' : var = bytarr(x)
        '2' : var = bytarr(x,y)
        '3' : var = bytarr(x,y,z)
        '4' : var = bytarr(x,y,z,t)
      ENDCASE
    ENDIF
           
    READU, ounit, var

    name = STRUCT.VARIABLES[i]
    
    DATA = CREATE_STRUCT(DATA, name, var)
  ENDFOR

  FREE_LUN, ounit

ENDELSE

RETURN, data

END