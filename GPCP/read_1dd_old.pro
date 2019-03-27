;---------------------------------------------------------------
; read_1dd_file.pro
;
; This IDL source file contains the read_1DD procedure, which reads all
; the data in a 1DD binary data file.  The call is exactly the same for
; the precip and error files.  Recall that the data files vary in length 
; depending on the number of days in the month, so the data array will
; vary in length.  
;
; The read_1DD procedure swaps the bytes of the data arrays if needed.
;
; This source file also contains the read_1DD_header procedure, which
; reads just the header of one of these binary files.
;
; Instructions:
;
; * Type "idl" at the UNIX command prompt to start IDL.
; * Type ".run read_1dd_file.pro" to compile the procedures.
; * Type "read_1DD, FILE, STRUC" where 
;   "FILE"  = user-specified name of the file to be read, which must 
;             be contained in double quotes (" ") if it contains 
;             characters that are meaningful to the IDL command-line 
;             interpreter, such as ".", and 
;   "STRUC" = user-specified name of the data structure that will 
;             contain the data read from the file; it contains two 
;             fields that are referenced as
;             STRUC.header = ASCII header (size 1440 bytes), and 
;             STRUC.data   = floating-point data, which contains
;                            whatever field is carried in the file
;                            specified on the command line (size
;                            360x180xN, N=28-31 depending on month).
;
; Change log:
; G.J. Huffman/SSAI       02/24/2008 Adapt read_rt_file.pro
; G.J. Huffman/SSAI       03/11/2008 Documentation; change internal
;                                    names "data" and "precip" to 
;                                    "struc" and "data"
;---------------------------------------------------------------


	pro read_1DD_num_days, file, num_days
;-----------------------------------------
;	The "days" metadata is days=1-nn, where nn is the number
;	of days in the month, which is what we want for the 3rd 
;	dimension.  Nence the "+7" in strmid.
;-----------------------------------------
	num_lon		= 360
	header		= bytarr( num_lon*4 )

	close,1
	openr,1, file
	readu,1, header
	close,1

	header		= strtrim( string(header), 2 )
	days		= strpos( header, 'days=' )
	num_days	= strmid( header, days+7, 2 )

	end

	pro create_1DD_struct, num_days, struc
;-----------------------------------------
;	Set up the data structure for output.
;-----------------------------------------
	num_lon		= 360
	num_lat		= 180

	struc = { header:	bytarr(num_lon*4), $
	          data:		fltarr(num_lon,num_lat,num_days) $
	  }

	end

	pro byte_swap_1DD, struc
;-----------------------------------------
;	Swap bytes if needed.
;-----------------------------------------
;
; ----- Determine byte order of system and of file (keyed to "machine=
;	Silicon Graphics").
;
         arch            = strlowcase( !version.arch )

         if (arch eq 'x86') OR (arch eq 'alpha') OR (arch eq 'i386') OR (arch eq 'x86_64') $
           then system_byte_order       = 'little_endian' $
           else system_byte_order       = 'big_endian'

	if strpos( string(struc.header), 'Silicon') ne -1 $
	  then file_byte_order		= 'big_endian' $
	  else file_byte_order		= 'little_endian'
;
; ----- If necessary, swap the bytes of the float variables.
;
	if system_byte_order ne file_byte_order then begin
	  print, 'byte_swap_1DD: warning: swapping bytes...'
	  struc.data		= swap_endian( struc.data )
	endif

	end

	pro read_1DD, file, struc
;-----------------------------------------
;	The main procedure; create the data structure, read both 
;	header and data, and swap bytes if needed.
;-----------------------------------------

	read_1DD_num_days, file, num_days
	create_1DD_struct, num_days, struc

	close,1
	openr,1, file
	readu,1, struc
	close,1

       ;; swap bytes on little endian systems
	byte_swap_1DD, struc
  
  ;=== Append longitude and latitudes to structure
  struc = CREATE_STRUCT(struc, 'LON', INDGEN(360)+0.5, 'LAT', -1*INDGEN(180)+89.5)
	end

	pro read_1DD_header, file, header
;-----------------------------------------
;	The procedure to just read the header.
;-----------------------------------------
	num_lon		= 360
	header		= bytarr( num_lon*4 )

	close,1
	openr,1, file
	readu,1, header
	close,1

	header		= str_sep( strtrim(string(header),2), ' ' )

	end

;-----------------------------------------
;	Help.
;-----------------------------------------

	print, ' '
	print, 'read_1DD, FILE, HEADER'
	print, '"FILE"  = user-specified name of the file to be read,'
	print, '          which must be contained in double quotes (" ")'
	print, '          if it contains characters that are meaningful to'
	print, '          the IDL command-line interpreter, such as "."'
	print, '"STRUC" = user-specified name of the data structure that'
	print, '          will contain the data read from the file; it'
	print, '          contains two fields that are referenced as'
	print, '          STRUC.header = ASCII header (size 1440 bytes)'
	print, '          STRUC.data   = floating-point data, which'
	print, '                         contains whatever field is'
	print, '                         carried in the file specified on'
	print, '                         the command line (size 360x180xN,'
	print, '                         N=28-31 depending on month)'
	print, ' '
	print, 'read_1DD_header, FILE, HEADER'
	print, '"FILE"   = user-specified name of the file to be read;'
	print, '           double-quoting might be needed'
	print, '"HEADER" = user-specified name of the file header array'
	print, '           (size 1440 bytes)'
	print, ' '

	end
