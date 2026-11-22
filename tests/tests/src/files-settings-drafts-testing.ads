--  What the suite reaches of Files.Settings.Drafts that is not part of its interface.
package Files.Settings.Drafts.Testing is

   --  Validate a settings draft without changing a settings model.
   --
   --  @param Draft Draft to validate.
   --  @return Validation result containing deterministic diagnostic key.
   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result;

end Files.Settings.Drafts.Testing;
