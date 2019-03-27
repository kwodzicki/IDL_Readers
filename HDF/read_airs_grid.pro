; NAME OF THIS FILE: 
; FUNCTION read_airs_grid.pro
 
; AUTHOR AND CHANGE HISTORY: 
; Stephen Licata (SL)
 
; Created by Stephen Licata (SL) on 03-17-2005.
; Updated on 12-05-2006 by SL.
;   Upper-case letters removed from program name and the 'compile_opt idl2'
;   line was added to enforce standard syntax for vector referencing and funmction calls.
; Updated on 05-16-2007 by SL.
;   New option (4) added for "content_flag" to dump the list of all parameters within a grid.
; Updated on 08-01-2007 by SL.
;   Corrected code (around Line 163) that treated a one-item content_list as an default (empty) list and
;   was returning ALL parameter values instead of just the single data set.
;
; DESCRIPTION:
; This function reads a Level 3 granule data file in the HDF-EOS grid format
; and extracts one or more data items from a grid structure within the data file.
; These data items could be actual data points or it could be characteristics
; about the data grid itself, such as grid name and coordinates.
;
 
; APPLICABLE INSTRUMENTS: 
; Atmospheric Infrared Sounder (AIRS)
; Advanced Microwave Sounding Unit-A (AMSU-A)
 
; APPLICABLE DATA FILE TYPES:
; Level 3 - Data products in which parameters are binned into grids one degree square in lat/lon.

; INPUT ARGUMENTS (REQUIRED)
;
; filename     - The fully qualified path to a Level 3 EOS-HDF grid format granule file.
;
; content_flag - An integer (0-4) that specifies the type of data to be extracted, as follows:
;                0: An array of the names of the grid(s) in that file.
;                1: The name and values of the grid's dimension parameters.
;                2: The name and values of the grid's attribute parameters.
;                3: The name and values of the grid's data field parameters.
;                4: An array of the data field names within a specific grid.
;
; INPUT ARGUMENTS [OPTIONAL]:
;
; INPUT OPTIONS:
; content_list - An array of names for the content items to be returned. If left unspecified,
;                the function will return ALL the parameters in that content category.
; gridname     - A text expression for the data grid within the granule file that is to be
;                examined. This function will only process one data grid at a time. In the
;                (typical) case that there is only ONE data grid in the granule file, this
;                argument can be left unspecified.
;
; OUTPUTS:
; buffer       - IDL data structure whose content is based on "content_flag".
;                Option 0: buffer will be a string array of all the grid names within a file.
;                Option 4: buffer will be a string array of all the parameter names within a specified grid.
;                Options 1-3: buffer will be an anonymous IDL data structure in which each member
;                has a "name" and a "data" component, which are actual data values.
;
;
; RETURN VALUE:
; status       - "0" for success and "-1" for failure.
;
; SIDE EFFECTS:
; None.
;
; CAVEATS: 
;              After creating the output structure "buffer", when data are actually extracted into pairs
;              of parameter name/values, a "help,buffer,/struct" command will show the data rganization
;              of the buffer structure but all the parameter names will be shown in upper-case letters.
;              You will still need to use the case-sensitive name of a parameter to actually access that
;              portion of the buffer. For example. "print,buffer.SurfAirTemp_A[1,2:4]".
;*****************************************************************************************************

   function read_airs_grid,filename,content_flag,buffer,content_list=content_list,gridname=gridname

; This enforces the use of square brackets for defining and referencing vectors.
; It also enforces the use of parentheses for function calls.
   compile_opt idl2

   prog_name = 'read_airs_grid'

   type_list = ['grid','dimension','attribute','field','field']

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
   fid      = EOS_GD_OPEN(filename,/READ)

; Abort the program if the file does not exist or cannot be read.
   if (fid le 0) then begin
      print,prog_name,': ERROR - ',filename,' could not be opened.'
      status = EOS_GD_CLOSE(fid)
      return,-1
   endif

; Get the number of data grids in the file (normally just 1)
   ngrid  = EOS_GD_INQGRID(filename,gridlist)

; Abort the program if no data grid(s) is/are found.
   if (ngrid le 0) then begin
      print,prog_name,': ERROR - ',filename,' has no data grid.'
      status = EOS_GD_CLOSE(fid)
      return,-1
   endif

; If only the grid list is requested, return that text string and end the program.
   if (content_flag eq 0) then begin
      buffer  = strsplit(gridlist,',',/extract)
      status = EOS_GD_CLOSE(fid)
      return,0
   endif

; Only continue processing if the data set is confined to a single grid.
   if (n_elements(gridname) eq 1) then begin
      gridname = gridname
   endif else if (ngrid eq 1) then begin
      gridname = gridlist
   endif else begin
      print,prog_name,': ERROR - only one data grid can be read at a time.'
      status = EOS_GD_CLOSE(fid)
      return,-1
   endelse

; Attach an ID to this grid.
   grid_id = EOS_GD_ATTACH(fid,gridname)

; Abort the program if this data grid cannot be accessed.
   if (grid_id le 0) then begin
      print,prog_name,': ERROR - Could not attach to grid ',gridname  
      status = EOS_GD_DETACH(grid_id)
      status = EOS_GD_CLOSE(fid)
      return,-1
   endif

; If only the total field list for a single grid is requested, return that text string and end the program.
   if (content_flag eq 3 or content_flag eq 4) then begin
      nflds        = EOS_GD_INQFIELDS(grid_id,fieldlist,rank,numbertype)
      if (nflds gt 0) then begin
         field_list = strsplit(fieldlist,',',/extract)
      endif
   end   

; Just return the list of field name.
   if (content_flag eq 4) then begin
      buffer    = field_list
      status    = EOS_GD_DETACH(grid_id)
      status    = EOS_GD_CLOSE(fid)
      return,0
   endif
   
; ###################################################################
; Assemble the content list (e.g., parameter names) to be extracted
; if this information has not already been provided as an input argument.
   if (n_elements(content_list) eq 0) then begin

; Each data type has its own extraction routine.
      case content_flag of
         1: begin
               ndim         = EOS_GD_INQDIMS(grid_id,dimname,dims)
               if (ndim gt 0) then begin
                  content_list = strsplit(dimname,',',/extract)
               endif else begin
                  print,'ERROR - The ',gridname,' grid has no dimensions.'
                  status = EOS_GD_DETACH(grid_id)
                  status = EOS_GD_CLOSE(fid)
                  return,-1
               endelse
            end
         2: begin
               nattrib      = EOS_GD_INQATTRS(grid_id,attrlist)
               if (nattrib gt 0) then begin
                  content_list = strsplit(attrlist,',',/extract)
               endif else begin
                  print,'ERROR - The ',gridname,' grid has no attributes.'
                  status = EOS_GD_DETACH(grid_id)
                  status = EOS_GD_CLOSE(fid)
                  return,-1
               endelse
            end
         3: begin
               if (n_elements(field_list) gt 0) then begin
                  content_list   = field_list
               endif else begin
                  print,'ERROR - The ',gridname,' grid has no data fields.'
                  status = EOS_GD_DETACH(grid_id)
                  status = EOS_GD_CLOSE(fid)
                  return,-1
               endelse
            end
      else: begin
               print,prog_name,': ERROR - No content list (based on content flag) was generated.'
               status = EOS_GD_DETACH(grid_id)
               status = EOS_GD_CLOSE(fid)
               return,-1
            end
      endcase
   endif

; Abort the program if the content list is just a single blank string entry.
   if (n_elements(content_list) eq 1) and (strlen(content_list[0]) eq 0) then begin
      print,prog_name,': ERROR - No set of ',type_list[content_flag],' parameter names was specified.'
      status = EOS_GD_DETACH(grid_id)
      status = EOS_GD_CLOSE(fid)
      return,-1
   endif

; Abort the program if the content list is still undefined.
   if (n_elements(content_list) eq 0) then begin
      print,prog_name,': ERROR - No set of ',type_list[content_flag],' parameter names was specified.'
      status = EOS_GD_DETACH(grid_id)
      status = EOS_GD_CLOSE(fid)
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
               item_val = EOS_GD_DIMINFO(grid_id,item_name)
               if (item_val ne -1) then begin
                  fail = 0
               endif
            end
; ------------------------------------------------------------------
         2: begin
               fail     = EOS_GD_READATTR(grid_id,item_name,item_val)
            end
; ------------------------------------------------------------------
         3: begin
               fail     = EOS_GD_READFIELD(grid_id,item_name,item_val)
            end
; ------------------------------------------------------------------
      else: begin
               print,prog_name,': ERROR - Content flag must be a dimension(1), attribute(2) or field(3).'
               status = EOS_GD_DETACH(grid_id)
               status = EOS_GD_CLOSE(fid)
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

; Detach from the data grid.
   status = EOS_GD_DETACH(grid_id)

; Close the file.
   status = EOS_GD_CLOSE(fid)


   return,0

end

