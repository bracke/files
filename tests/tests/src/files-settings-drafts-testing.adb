package body Files.Settings.Drafts.Testing is

   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result renames Files.Settings.Drafts.Validate_Draft;

end Files.Settings.Drafts.Testing;
