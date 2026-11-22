with Ada.Strings.Unbounded;

package body Files.Operations.Paste.Testing is

   use Ada.Strings.Unbounded;

   function Finalize_Paste_With_Kept_Copy
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Dest, Source, Identity, Tree_Revision : String)
      return Operation_Result is
   begin
      return Finalize_Paste_Execution
        (Model, Settings, Error_Key,
         (Dest_Path     => To_Unbounded_String (Dest),
          Source_Path   => To_Unbounded_String (Source),
          Identity      => To_Unbounded_String (Identity),
          Tree_Revision => To_Unbounded_String (Tree_Revision)));
   end Finalize_Paste_With_Kept_Copy;

   procedure Begin_Paste_Execution
     (Model           : in out Files.Model.Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
     renames Files.Operations.Paste.Begin_Paste_Execution;

end Files.Operations.Paste.Testing;
