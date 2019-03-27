FUNCTION READ_GOES_HDW, file
;+
; Name:
;   READ_GOES_HDW 
; Purpose:
;   An IDL function to read in data from the GOES high density wind ASCII files
;   https://www.star.nesdis.noaa.gov/smcd/opdb/goes/winds/
; Inputs:
;   file   : Full path to the file
; Outputs:
;   Returns structure containing information
; Keywords:
;   None.
; Author and History:
;   Kyle R Wodzicki     Created 18 Mar. 2018
;-
COMPILE_OPT IDL2

l = ''
OPENR, iid, file, /GET_LUN  

READF, iid, l
READF, iid, l

UV   = LIST()
LON  = LIST()
LAT  = LIST()
DATE = LIST()
PRES = LIST()
WHILE NOT EOF(iid) DO BEGIN
  READF, iid, l
  tmp = STRSPLIT(l, /EXTRACT)
  yy  = LONG( STRMID(tmp[2],0,4) )
  dd  = LONG( STRMID(tmp[2],4,3) )-1
  hr  = LONG( STRMID(tmp[3],0,2) )
  mn  = LONG( STRMID(tmp[3],2,2) )
  sc  = LONG( STRMID(tmp[3],4,2) )
  date.ADD, GREG2JUL(1,1,yy,hr,mn,sc) + dd
  lat.ADD,  FLOAT( tmp[4] )
  lon.ADD,  -FLOAT( tmp[5] )
  pres.ADD, LONG(  tmp[6] )

	theta = !DtoR * (270 - FLOAT( tmp[8] ) )
  speed = FLOAT( tmp[7] )
	UV.ADD, speed * [COS(theta), SIN(theta)]  
ENDWHILE

FREE_LUN, iid
uv = uv.ToArray(/No_Copy)


RETURN, {date : date.ToArray(/No_Copy), $
         pres : pres.ToArray(/No_Copy), $
         lon  : lon.ToArray(/No_Copy),  $
         lat  : lat.ToArray(/No_Copy),  $
         u    : uv[*,0], $
         v    : uv[*,1]}
END