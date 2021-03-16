FUNCTION RSS_TMI_FILESEARCH, version, $
  COUNT=count, MONTHLY=MONTHLY, D3D=d3d
;+
; Name:
;   RSS_TMI_FILESEARCH
; Purpose:
;   Function to return file paths for all files at given resolution
; Inputs:
;   version : (float, optional) Specify data version
; Keywords:
;   monthly : Set to get month file paths; default is daily
;   D3D     : set to get 3-day mean file paths; default is daily
;   COUNT   : Set to named variable that will contain number of files upon return
; Returns:
;   List of files paths if files found, -1 otherwise
;-
COMPILE_OPT IDL2

IF N_ELEMENTS(version) EQ 0 THEN version = 7.1
vers = STRING(version, FORMAT="('v',F04.1)")
root = FILEPATH('bmaps_'+vers, ROOT_DIR=!RSS_Data, SUBDIRECTORY='tmi')

vers = STRING(version, FORMAT="('v',F3.1)")
IF KEYWORD_SET(d3d) THEN $
  pattern = 'f12_*'+vers+'_d3d.gz' $
ELSE $
  pattern = 'f12_*'+vers+'.gz' 

files = FILE_SEARCH(root, pattern, COUNT=count)

IF KEYWORD_SET(d3d) THEN BEGIN
  RETURN, files
ENDIF ELSE IF KEYWORD_SET(monthly) THEN BEGIN
  pattern = STRREP(pattern, '*', '[0-9]{6}')
ENDIF ELSE BEGIN
  pattern = STRREP(pattern, '*', '[0-9]{8}')
ENDELSE

id = WHERE( STREGEX(files, pattern, /BOOLEAN), count )

IF count GT 0 THEN RETURN, files[id] ELSE RETURN, -1

END 
