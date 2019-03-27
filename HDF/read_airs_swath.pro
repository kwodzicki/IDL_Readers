; FUNCTION read_airs_swath
;
; Created by Stephen Licata (SL) on 03-17-2005.
; Updated on 12-05-2006 by SL.
;   Upper-case letters removed from program name and the 'compile_opt idl2'
;   Line was added to enforce standard syntax for vector referencinga nd funmction calls.
; Updated on 05-18-2006 by SL.
;   The content_flag = 4 option was added to enable a dump of the swath's data fields.
;
; DESCRIPTION:
; This function reads a Level 1/2 granule data file in the HDF-EOS swath format
; and extracts one or more data items from a swath structure within the data file.
; These data items could be actual data points or it could be characteristics
; about the data swath itself, such as swath name and coordinates.
;
; INPUT ARGUMENTS (REQUIRED)
;
; filename  - The fully qualified path to a Level 1/2 EOS-HDF swath format granule file.
;
; content_flag - An integer (0-4) that specifies the type of data to be extracted, as follows:
;                0: A string array showing the name of the swath(s) in that file.
;                1: The name and values of the swath's dimension parameters.
;                2: The name and values of the swath's attribute parameters.
;                3: The name and values of the swath's data field parameters.
;                4: A string array showing the names of all parameters in a specific swath.
;
; INPUT ARGUMENTS [OPTIONAL]:
;
; content_list - An array of names for the content items to be returned. If left unspecified,
;                the function will return ALL the parameters in that content category.
;
; swathname    - A text expression for the data swath within the granule file that is to be
;                examined. This function will only process one data swath at a time. In the
;                (typical) case that there is only ONE data swath in the granule file, this
;                argument can be left unspecified.
;
; OUTPUTS:
;
; buffer       - An IDL data structure whose content is based on "content_flag".
;                Option 0: buffer will be a string array of all the swath names within a file.
;                Option 4: buffer will be a string array of all the parameter names within a specified swath.
;                Options 1-3: buffer will be an anonymous IDL data structure in which each member
;                has a "name" and a "data" component, which are actual data values.
;
; RETURN VALUES:
;
; status       - "0" for success and "-1" for failure.
;
; SIDE EFFECTS
;
;              Options 3 and 4, by default, retrieve NOTH the geo-location AND science data fields.
; CAVEATS:
;              After creating the output structure "buffer", when data are actually extracted into pairs 
;              of parameter name/values, a "help,buffer,/struct" command will show the data organization
;              of the buffer structure but all the parameter names will be shown in upper-case letters.
;              You will still need to use the case-sensitive name of a parameter to actually access that
;              portion of the buffer. For example "print,buffer.PSurfStd[2,5:8]" 
;
;*****************************************************************************************************

   function read_airs_swath,filename,content_flag,buffer,content_list=content_list,swathname=swathname

   prog_name = 'read_airs_swath'

; This enforces the use of square brackets for defining and referencing vectors.
; It also enforces the use of parentheses for function calls.
   compile_opt idl2

   type_list = ['swath','dimension','attribute','field','field']

; Abort the program if no data file has been provided.
   if (n_elements(filename) eq 0) then begin
      print,prog_name,': ERROR - No input filename was specified.'
      return,-1
   endif

; Abort the program if no data type has been specified.
   if (n_elements(content_flag) eq 0) then begin
      print,prog_name,': ERROR - No content code (type) was provided.'
      return,-1
   endif

; Get a file id value.
   fid      = EOS_SW_OPEN(filename,/READ)

; Abort the program if the file does not exist or cannot be read.
   if (fid le 0) then begin
      print,prog_name,': ERROR - ',filename,' could not be opened.'
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif

; Get the number of data swaths in the file (normally just 1)
   nswath     = EOS_SW_INQSWATH(filename,swathlist)

; Abort the program if no data swath(s) is/are found.
   if (nswath le 0) then begin
      print,prog_name,': ERROR - ',filename,' has no data swath.'
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif

; Get the list of swaths for later use.
   swath_list = strsplit(swathlist,',',/extract)

; If only the swath list is requested, return that text string and end the program.
   if (content_flag eq 0) then begin
      buffer = swath_list
      status = EOS_SW_CLOSE(fid)
      return,0
   endif

; Only continue processing if the data set is confined to a single swath.
   if (n_elements(swathname) eq 1) then begin
      swathname = swathname
   endif else if (nswath eq 1) then begin
      swathname = swath_list[0]
   endif else begin
      print,prog_name,': ERROR - only one data swath can be read at a time.'
      print,prog_name,': Swath list = ' + swathlist
      status = EOS_SW_CLOSE(fid)
      return,-1
   endelse

; Attach an ID to this swath.
   swath_id = EOS_SW_ATTACH(fid,swathname)

; Abort the program if this data swath cannot be accessed.
   if (swath_id le 0) then begin
      print,prog_name,': ERROR - Could not attach to swath ',swathname  
      status = EOS_SW_DETACH(swath_id)
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif

; Get the list of all geo-location and science data fields for later use.
   ngeo         = EOS_SW_INQGEOFIELDS(swath_id,geolist,rank,numbertype)
   nflds        = EOS_SW_INQDATAFIELDS(swath_id,fieldlist,rank,numtype) 

; Abort now if there are no data fields.
   if ((ngeo + nflds) lt 1) then begin
      print,prog_name,': ERROR - The '+ swathname + ' swath has no data fields.' 
      status = EOS_SW_DETACH(swath_id)
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif
      
; Otherwise, concatenate the two strings of names. 
   if (ngeo gt 0) then begin
      tmp      = geolist
      if (nflds gt 0) then begin
         tmp      = [tmp+','+fieldlist]
      endif
   endif else begin
      if (nflds gt 0) then begin
         tmp   = fieldlist
      endif else begin
         tmp   = ['']
      endelse
   endelse

; Then parse the text string of names to make a String array.
   if (n_elements(tmp) gt 0) then begin
      field_list = strsplit(tmp,',',/extract)
   endif else begin
      field_list[0] = ' '
   endelse

; Stop here if all we need is the list of data fields.
  if (content_flag eq 4) then begin
     buffer    = field_list
     status = EOS_SW_DETACH(swath_id)
     status = EOS_SW_CLOSE(fid)
     return,0
  endif

; ###################################################################
; Assemble the content list (e.g., parameter names) to be extracted
; if this information has not already been provided as an input argument.
   if n_elements(content_list) eq 0 then begin

; Each data type has its own extraction routine.
      case content_flag of
         1: begin
               ndim         = EOS_SW_INQDIMS(swath_id,dimname,dims)
               if (ndim lt 1) then begin
                  print,prog_name,': ERROR - The '+ swathname + ' swath has no dimension data.' 
                  status = EOS_SW_DETACH(swath_id)
                  status = EOS_SW_CLOSE(fid)
                  return,-1
               endif
               content_list = strsplit(dimname,',', /extract)
            end
         2: begin
               nattrib      = EOS_SW_INQATTRS(swath_id,attrlist)
               if (nattrib lt 1) then begin
                  print,prog_name,': ERROR - The '+ swathname + ' swath has no attribute data.' 
                  status = EOS_SW_DETACH(swath_id)
                  status = EOS_SW_CLOSE(fid)
                  return,-1
               endif
               content_list = strsplit(attrlist,',',/extract)
            end
         3: begin
               content_list = field_list;
            end
      else: begin
               print,prog_name,': ERROR - No content list (based on content flag) was generated.'  
               status = EOS_SW_DETACH(swath_id)
               status = EOS_SW_CLOSE(fid)
               return,-1
            end
      endcase
   endif

; Abort the program if the content list is just a single blank string entry.
   if (n_elements(content_list) eq 1) and (strlen(content_list[0]) eq 0) then begin
      print,prog_name,': ERROR - No set of ',type_list[content_flag],' parameter names was specified.'
      status = EOS_SW_DETACH(swath_id)
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif

; Abort the program if the content list is still undefined.
   if (n_elements(content_list) eq 0) then begin
      print,prog_name,': ERROR - No set of ',type_list[content_flag],' parameter names was specified.'
      status = EOS_SW_DETACH(swath_id)
      status = EOS_SW_CLOSE(fid)
      return,-1
   endif

; Now get the content (values) for each item in the content list.
   num_items = n_elements(content_list)
   j         = 0
   for i=0,num_items-1 do begin
      item_name = content_list[i]

; Discard any parameter names that have a '=' sign in the name.
; NOTE: This is an optional feature based on experience with these data files.
      bad_pos = strpos(item_name,'=')
      if (bad_pos[0] ne -1) then continue

; Initially assume there is no value to go with this parameter name.
      fail = -1

; Extract the data value based on the parameter name and data type.
      case content_flag of
; ------------------------------------------------------------------
         1: begin
               item_val = EOS_SW_DIMINFO(swath_id,item_name)
               if (item_val ne -1) then begin
                  fail = 0
               endif
            end
; ------------------------------------------------------------------
         2: begin
               fail     = EOS_SW_READATTR(swath_id,item_name,item_val)
            end
; ------------------------------------------------------------------
         3: begin
               fail     = EOS_SW_READFIELD(swath_id,item_name,item_val)
            end
; ------------------------------------------------------------------
      else: begin
               print,prog_name,': ERROR - Content flag must be a dimension(1), attribute(2) or field(3).'
               status = EOS_SW_DETACH(swath_id)
               status = EOS_SW_CLOSE(fid)
               return,-1
            end  
      endcase

; Now replace any '.' characters in the parameter name with '_'.
      pos = strpos(item_name,'.')
      while (pos ne -1) do begin
         first_part = strmid(item_name,0,pos)
         last_part  = strmid(item_name,pos+1)
         tmp_name   = first_part + '_' + last_part
         item_name  = tmp_name
         pos        = strpos(item_name,'.')
      endwhile

; Build a name/value pair for the output buffer structure.
; Be sure to skip this item if the 'name' part is already part of the structure.
      if (not fail) then begin
         if (j eq 0) then begin
            buffer = create_struct(item_name,item_val)
         endif else begin
            tag_list = Tag_Names(buffer)
            tag_loc  = where(tag_list eq STRUPCASE(item_name))
            if (tag_loc[0] eq -1) then begin
               buffer = create_struct(buffer,item_name,item_val)
            endif
         endelse
         j = j + 1
      endif else begin
         print,prog_name,': ERROR - Failed reading ',type_list[content_flag],' ',item_name
      endelse

   endfor

; Detach from the data swath.
   status = EOS_SW_DETACH(swath_id)

; Close the file.
   status = EOS_SW_CLOSE(fid)

   return,0

end

