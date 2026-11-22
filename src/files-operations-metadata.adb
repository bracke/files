with Files.File_System;
with Files.File_System.Trash;
with Files.File_System.Permissions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Undo.Payloads;
with Hostkit.Metadata;
with Hostkit;
with Files.Operations.Support;
with Files.Operations.Undo_Recording;
with Files.Model.Selection;
with Files.Undo.History;

package body Files.Operations.Metadata is

   use Ada.Strings.Unbounded;
   use type Files.Undo.History.Undo_Action_Kind;
   use Files.Operations.Support;

   --  The undo history is recorded by Files.Operations.Undo_Recording; these name it
   --  here for the bodies that record.
   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
     renames Files.Operations.Undo_Recording.Record_Undo;

   --  Items an action published (Files.Operations.Undo_Recording.Published).
   function Published
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector
     renames Files.Operations.Undo_Recording.Published;

   function Ownership_Text
     (User_Id, Group_Id : Files.Types.Account_Id; User_Name, Group_Name : String)
      return String
   is
     (Files.Undo.Payloads.Ownership_Text
        ((User_Id, Group_Id, To_Unbounded_String (User_Name), To_Unbounded_String (Group_Name))));

   --  Which file metadata an editable-selection check is about.
   type Editable_Metadata is (Ownership_Metadata, Permissions_Metadata);

   --  The one check behind Permissions_ and Ownership_Editable_Selection:
   --  exactly one real (non-temporary) item is selected outside a trash's
   --  files directory, the platform can change What, and the item's What
   --  was read.
   function Metadata_Editable_Selection
     (Model : Files.Model.Window_Model;
      What  : Editable_Metadata)
      return Boolean
   is separate;

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is (Metadata_Editable_Selection (Model, Permissions_Metadata));

   --  What a permission or ownership change on Path does once it is made:
   --  record its undo (Old_Text back, New_Text forward, the file's identity
   --  as provenance), reload the folder and clear the error.
   function Finish_Attribute_Change
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind     : Files.Undo.History.Undo_Action_Kind;
      Path     : String;
      Identity : Files.Types.UString;
      Old_Text : String;
      New_Text : String)
      return Operation_Result
   is
   begin
      Record_Undo
        (Model, Kind,
         Published
           (Files.Undo.History.Undo_Item_Vectors.To_Vector
              ((From          => To_Unbounded_String (Path),
                To            => To_Unbounded_String (Old_Text),
                Forward       => To_Unbounded_String (New_Text),
                Identity      => Identity,
                Tree_Revision => Null_Unbounded_String), 1)));
      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, Files.Model.Selection.Selected_Name (Model));
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Path);
   end Finish_Attribute_Change;

   function Ownership_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is (Metadata_Editable_Selection (Model, Ownership_Metadata));

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Files.Types.Account_Id;
      Group_Id : Files.Types.Account_Id;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   procedure Focus_Ownership_Input
     (Model         : in out Files.Model.Window_Model;
      Editing_Group : Boolean)
   is separate;

   function Commit_Ownership_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

end Files.Operations.Metadata;
