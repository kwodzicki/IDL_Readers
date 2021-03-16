FUNCTION TRMM_PARSE_FILENAME, fileName
COMPILE_OPT IDL2

tmp = STRSPLIT(FILE_BASENAME(fileName), '.', /EXTRACT)

RETURN, {PRODUCT : tmp[0], $
         DATE    : tmp[1], $
         SWATH   : tmp[2], $
         VERSION : (STRSPLIT(tmp[3], '_', /EXTRACT))[0]}

END
