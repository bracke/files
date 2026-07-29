separate (Files.File_System)
   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy is
   begin
      return
        (Uses_Extension_Mapping     => True,
         Uses_Mime_Sniffing         => False,
         Parses_Image_Dimensions    => True,
         Parses_Text_Encoding       => True,
         Parses_Archive_Entry_Count => True,
         Parses_Pdf_Page_Markers    => True,
         Parses_Media_Codecs        => False,
         Parses_Office_Package_Info => True);
   end Filetype_Metadata_Policy_Of_Current_Implementation;
