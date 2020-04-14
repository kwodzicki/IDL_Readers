FUNCTION __GET_VAR_INFO, gid, VARIABLES = variables
;+
; Name:
;   __GET_VAR_INFO
; Purpose:
;   An IDL function to iterate over all attributes of a grib variable
; Inputs:
;   gid   :
; Outputs:
;   Returns an IDL HASH with all information for the variable
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki
;-
  COMPILE_OPT IDL2, HIDDEN
  info = HASH()                                                                 ; Initialize a hash, similar to python dictionary
  iter = GRIB_KEYS_ITERATOR_NEW(gid)                                            ; Initialize key iterator for gid
  res  = GRIB_KEYS_ITERATOR_NEXT(iter)                                          ; Get the next key in the iterator
  WHILE res EQ 1 DO BEGIN                                                       ; While there is another key; i.e., GRIB_KEYS_ITERATOR_NEXT returns True
    name = GRIB_KEYS_ITERATOR_GET_NAME(iter)                                    ; Get the name of the current key
    CATCH, error                                                                ; Catch any error; i.e., return to this point on error
    IF error NE 0 THEN BEGIN                                                    ; If there is an error
      res = GRIB_KEYS_ITERATOR_NEXT(iter)                                       ; Move to the next key in the iterator
      IF res EQ 0 THEN BREAK                                                    ; If no next key, i.e., GRIB_KEYS_ITERATOR_NEXT returns False, break out of while loop
      name = GRIB_KEYS_ITERATOR_GET_NAME(iter)                                  ; Get the name of the key
    ENDIF                                                                       ; ENDIF
    data = (GRIB_GET_SIZE(gid, name) GT 1) ? GRIB_GET_ARRAY(gid, name) $        ; If the size of the value is greater than one, then use GRIB_GET_ARRAY function
                                           : GRIB_GET(gid, name)                ; Else, use GRID_GET function
    info[name] = data                                                           ; Store data in the hash
    res  = GRIB_KEYS_ITERATOR_NEXT(iter)                                        ; Get the next key in the iterator
  ENDWHILE                                                                      ; ENDWHILE
  GRIB_KEYS_ITERATOR_DELETE, iter                                               ; Delete the iterator after looping is done

  IF info.HasKey('values') THEN BEGIN                                           ; If the info hash has a 'values' key
    IF info.HasKey('Ni') AND info.HasKey('Nj') AND info.HasKey('Nk') THEN $     ; If the data is 3D, i.e., has i, j, k counts
      dims = [ info['Ni'], info['Nj'], info['Nk'] ] $                           ; Set dimensions using all three (3) values
    ELSE IF info.HasKey('Ni') AND info.HasKey('Nj') THEN $                      ; Else, if data is 2D, i.e., has i, j counts
      dims = [ info['Ni'], info['Nj'] ]                                         ; Set dimensions using two (2) values
    IF N_ELEMENTS(dims) GT 0 THEN info['values'] = REFORM(info['values'], dims) ; Reform the data to the 'correct' size
  ENDIF                                                                         ; ENDIF
  RETURN, info                                                                  ; Return the info hash
END

FUNCTION __SORT_BY_LVL_TYPE, data, info, tag
;+
; Name:
;   __SORT_BY_LVL_TYPE
; Purpose:
;   An IDL function to sort variable info into level type in data hash
; Inputs:
;   data    : IDL HASH containing all data variables from file; being added to
;   info    : IDL HASH containing information for one GRIB handle
;   tag     : String containing tag for the info GRIB handle
; Outputs:
;   Returns updated data HASH
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki
;-
  COMPILE_OPT IDL2, HIDDEN
  lvlType = info['typeOfLevel']                                                 ; Get the level type for the info GRIB handle
  IF data.HasKey( lvlType ) EQ 0 THEN data[ lvlType ] = HASH()                  ; IF the level type does NOT exist in the data HASH, create a new HASH under the level type key
  IF data[lvlType].HasKey(tag) THEN BEGIN                                       ; IF the HASH under the level type has the tag key
    IF data[lvlType,tag].HasKey('values') AND info.HasKey('values') THEN BEGIN  ; IF the HASH under lvlType,tag has a 'values' key AND info has a values key
      IF SIZE(data[lvlType,tag,'values'],/TYPE) NE 11 THEN $                    ; IF the data under lvlType,tag,'values' is NOT an object; i.e., NOT a list
        data[lvlType,tag,'values'] = LIST( data[lvlType,tag,'values'] )         ; Move data into a list
      data[lvlType,tag,'values'].ADD, info['values']                            ; Add the new values to the list
    ENDIF                                                                       ; ENDIF
    IF data[lvlType,tag].HasKey('level') AND info.HasKey('level') THEN BEGIN    ; IF the HASH under lvlType,tag has a 'level' key AND info has a level key
      IF SIZE(data[lvlType,tag,'level'],/TYPE) NE 11 THEN $                     ; IF the data under lvlType,tag,'level' is NOT an object; i.e., NOT a list
        data[lvlType,tag,'level'] = LIST( data[lvlType,tag,'level'] )           ; Move data into a list
      data[lvlType,tag,'level'].ADD, info['level']                              ; Add the new values to the list
    ENDIF                                                                       ; ENDIF
  ENDIF ELSE $                                                                  ; ENDIF ELSE, there was no tag key in the data[lvlType] HASH
    data[lvlType,tag] = info                                                    ; Place the info HASH in the data HASH under the key lvlType,tag
  RETURN, data                                                                  ; Return the updated data HASH
END

FUNCTION READ_GRIB2, filename, VARIABLES = variables, STRUCT = struct
;+
; Name:
;   READ_GRIB2
; Purpose:
;   An IDL function to read in the data from a grib2 file. May not be
;   very general...
; Inputs:
;   filename : Full path to the file to read in.
; Outputs:
;   Returns structure with all variables and some information
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 13 Sep. 2018
;-
COMPILE_OPT IDL2

IF N_ELEMENTS(variables) GT 0 THEN $                                            ; If there is at least one variable requested
  IF ISA(variables, /SCALAR) THEN $                                             ; If variables is NOT an array
    variables = [variables]                                                     ; Convert to an array

data = HASH();                                                                  ; Initialize a hash, similar to python dictionary
fid  = GRIB_OPEN(filename)                                                      ; Open the grib file
gid  = GRIB_NEW_FROM_FILE(fid)                                                  ; Get GRIB handle from open file
WHILE gid NE !NULL DO BEGIN                                                     ; While the GRIB handle is NOT !NULL
  tag = GRIB_GET(gid, 'shortName')                                              ; Set tag to the 'shortname' attribute of the grid handle
  IF N_ELEMENTS(variables) GT 0 THEN $                                          ; If the variables keyword IS set
    IF TOTAL(STRMATCH(variables, tag, /FOLD_CASE), /INT) EQ 0 THEN BEGIN        ; If the tag does NOT match any of the variable names; case insensitive
      GRIB_RELEASE, gid                                                         ; Release the GRIB handle
      gid  = GRIB_NEW_FROM_FILE(fid)                                            ; Get the next GRIB handle in the file
      CONTINUE                                                                  ; Continue
    ENDIF                                                                       ; ENDIF
  info    = __GET_VAR_INFO(gid, VARIABLES = variables)                          ; Use the __GET_VAR_INFO function to get all information related to the GRIB handle
  IF info.HasKey( 'typeOfLevel' ) THEN data = __SORT_BY_LVL_TYPE(data,info,tag) ; If the info HASH has a 'typeOfLevel' tag, then run the __SORT_BY_LVL_TYPE function
  GRIB_RELEASE, gid                                                             ; Release the GRIB handle
  gid  = GRIB_NEW_FROM_FILE(fid)                                                ; Get a new GRIB handle
ENDWHILE                                                                        ; ENDWHILE
GRIB_CLOSE, fid                                                                 ; Close the GRIB file

lvlType = data.KEYS()                                                           ; Get types of levels in the data HASH; i.e., all the keys
FOR j = 0, N_ELEMENTS(lvlType)-1 DO BEGIN                                       ; Iterate over all the level types
  keys = data[ lvlType[j] ].KEYS()                                              ; Get all the keys for the jth level type
  FOR i = 0, N_ELEMENTS(keys)-1 DO BEGIN                                        ; Iterate over all the keys in the jth level type
    IF data[lvlType[j],keys[i]].HasKey('level') AND $                           ; If the HASH for the level and key has LEVEL attribute
       data[lvlType[j],keys[i]].HasKey('values') THEN $                         ; AND has a values attribute
      IF SIZE(data[lvlType[j],keys[i],'level'],/TYPE) EQ 11 THEN BEGIN          ; If the level attribute is an object; assume is list
        lvls = data[lvlType[j],keys[i],'level'].ToArray(/No_Copy)               ; Convert levels to an array
        tmp  = data[lvlType[j],keys[i],'values'].ToArray(/No_Copy, /Transpose)  ; Convert values to an array
        sid  = SORT(lvls);                                                      ; Get indicies for sorting the levels
        data[lvlType[j],keys[i],'level']  = lvls[sid]                           ; Set levels value to sorted levels
        data[lvlType[j],keys[i],'values'] = tmp[*,*,sid]                        ; Set values to values sorted by level
      ENDIF                                                                     ; END IF
    IF data[lvlType[j],keys[i]].HasKey('Ni') AND $                              ; If the HASH for the level and key has an i count
       data[lvlType[j],keys[i]].HasKey('Nj') THEN BEGIN                         ; AND has a j count
      nx = data[ lvlType[j],keys[i],'Ni' ]                                      ; Set nx to number of i points
      ny = data[ lvlType[j],keys[i],'Nj' ]                                      ; Set ny to number of i points
      IF data[lvlType[j],keys[i]].HasKey('longitudes') THEN $                   ; If the HASH for the level and key has a longitudes key
        data[ lvlType[j],keys[i],'longitudes' ] = REFORM($                      ; REFORM the longitudes to the proper size
          data[ lvlType[j],keys[i],'longitudes' ], nx, ny)
      IF data[lvlType[j],keys[i]].HasKey('latitudes') THEN $                    ; If the HASH for the level and key has a longitudes key
        data[ lvlType[j],keys[i],'latitudes' ] = REFORM($                       ; REFORM the latitudes to the proper size
          data[ lvlType[j],keys[i],'latitudes' ], nx, ny)
    ENDIF                                                                       ; END IF
    IF KEYWORD_SET(struct) THEN $                                               ; IF the struct keyword is set
      data[ lvlType[j],keys[i] ] = data[lvlType[j],keys[i]].ToStruct()          ; Convert the HASH for the level and key to a structure
  ENDFOR                                                                        ; END i
  IF KEYWORD_SET(struct) THEN $                                                 ; IF the struct keyword is set
    data[ lvlType[j] ] = data[ lvlType[j] ].ToStruct()                          ; Convert the HASH for the level to a structure
ENDFOR                                                                          ; END j
IF KEYWORD_SET(struct) THEN data = data.ToStruct()                              ; IF the struct keyword is set, convert the HASH to a structure

RETURN, data                                                                    ; RETURN data HASH (or structure depending on keywords)

END