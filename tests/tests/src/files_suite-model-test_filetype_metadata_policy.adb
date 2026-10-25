separate (Files_Suite.Model)
   procedure Test_Filetype_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Metadata_Policy : constant Files.File_System.Filetype_Metadata_Policy :=
        Files.File_System.Filetype_Metadata_Policy_Of_Current_Implementation;
   begin
      Assert (Metadata_Policy.Uses_Extension_Mapping, "metadata policy uses extension mappings");
      Assert (not Metadata_Policy.Uses_Mime_Sniffing, "metadata policy does not claim MIME sniffing");
      Assert (Metadata_Policy.Parses_Image_Dimensions, "metadata policy parses image dimensions");
      Assert (Metadata_Policy.Parses_Text_Encoding, "metadata policy parses text encoding");
      Assert (Metadata_Policy.Parses_Archive_Entry_Count, "metadata policy parses archive entry counts");
      Assert (Metadata_Policy.Parses_Pdf_Page_Markers, "metadata policy parses PDF page markers");
      Assert (not Metadata_Policy.Parses_Media_Codecs, "metadata policy does not claim media codecs");
      Assert (Metadata_Policy.Parses_Office_Package_Info, "metadata policy parses Office package info");
   end Test_Filetype_Metadata_Policy;
