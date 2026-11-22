with Files.Model;
with Files.Settings;

--  Test access to Files.Operations.Paste's private part.
package Files.Operations.Paste.Testing is

   --  Finalize_Paste_Execution with a failed move's kept copy.
   --  @param Model Window whose paste finishes.
   --  @param Settings Current settings.
   --  @param Error_Key Mid-run failure, or "".
   --  @param Dest The kept copy's path.
   --  @param Source Its still present source.
   --  @param Identity The copy's identity.
   --  @param Tree_Revision The copy's revision.
   --  @return The paste's result.
   function Finalize_Paste_With_Kept_Copy
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Dest, Source, Identity, Tree_Revision : String)
      return Operation_Result;

end Files.Operations.Paste.Testing;
