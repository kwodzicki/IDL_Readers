FUNCTION TRMM_DATADIR, product, date, $
  ROOT_DIR    = root_dir, $
  CHECK_EXIST = check_exist, $
  _EXTRA      = _extra
;+
; Name
;   TRMM_DATADIR
; Purpose:
;   Function to return top-level path to TRMM data given a product such as
;   1b01 or 2a25
; Inputs:
;   product (string) : Product to get data path for
;   date (JULDAY, optional) : IDL Julian date for data. If ommited,
;     will return top-level to given data product
; Keywords:
;   ROOT_DIR (string) : Root path to all TRMM data; is set will supersede the
;     !TRMM_Data system variable
;   CHECK_EXIST (bool) : Check if the directory exists before returning path.
;     If directory NOT exist, error raised.
;     Default is to check that directory exists. To disable, set CHECK_EXIST=0
; Returns:
;   path to top-level directory
; Directory structure:
;   Data must be structured as the GES DISC OPeNDAP for TRMM data found at:
;     https://disc2.gesdisc.eosdis.nasa.gov/opendap/
;   The structur is as follows:
;     TRMM_LX/
;       TRMM_PROD/
;   WHERE 'X' is the data level (1, 2, 3) and 'PROD' is the product (1B01)
; Note:
;   This function depends on the !TRMM_Data system variable to determine the
;   root directory for all TRMM data.
;   E.g.:
;     !TRMM_Data = /Volumes/data1/TRMM
;   This directory can contain various TRMM data directories for level1, level2,
;   TRMM PF, etc.
;
; RECOMMENDATIONS:
;   It is recommended to use the TRMM_Downloader class to download data so that
;   data paths match. When downloading, remember what OUTDIR you use as this
;   is the value that shoud be used for ROOT_DIR
;-

COMPILE_OPT IDL2

IF N_ELEMENTS(check_exist) EQ 0 THEN check_exist = 1B                         ; If check_exist NOT set, set to on

root    = (N_ELEMENTS(root_dir) EQ 1) ? root_dir : !TRMM_Data                 ; Set data root directory based on root_dir keyword
subdirs = ['TRMM_L'+STRMID(product,0,1), 'TRMM_'+STRUPCASE(product)]          ; Define subdirectories for data path based on product
IF N_ELEMENTS( date ) EQ 1 THEN BEGIN                                         ; If date input
  JUL2GREG, date, mm, dd, yy                                                  ; Get year,month,day of date
  ref     = GREG2JUL(1, 1, yy)                                                ; Get first of year
  julian  = GREG2JUL(mm, dd, yy) - ref + 1                                    ; Compute day of year
  subdirs = [subdirs, STRTRIM(yy, 2), STRING(julian, FORMAT="(I03)")]         ; Append year and julian day to subdirs array
ENDIF
path    = FILEPATH('', ROOT_DIR = root, SUBDIRECTORY = subdirs)               ; Build file path

IF KEYWORD_SET(check_exist) THEN $                                            ; If check_exist set
  IF FILE_TEST(path, /DIRECTORY) EQ 0 THEN $                                  ; If directory NOT exist
    MESSAGE, 'Directory does NOT exist: ' + path                              ; Error message

RETURN, path

END
