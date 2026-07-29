with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Types;

with Files.Operations.Support;

separate (Files.Operations)
package body Metadata is

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is
      Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
   begin
      return Files.Model.Selected_Count (Model) = 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
        and then Files.File_System.Supports_Permissions
        and then Item.Mode_Available
        and then Files.Model.Current_Path (Model) /= Files.File_System.Trash_Files_Directory;
   end Permissions_Editable_Selection;

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if not Permissions_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item      : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Path      : constant String := To_String (Item.Full_Path);
         Old_Mode  : constant Natural := Item.Mode_Bits;
         Mutation  : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Permissions (Path, New_Mode);
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;

         declare
            Undo_From    : Files.Types.String_Vectors.Vector;
            Undo_To      : Files.Types.String_Vectors.Vector;
            Undo_Forward : Files.Types.String_Vectors.Vector;
         begin
            Undo_From.Append (To_Unbounded_String (Path));
            Undo_To.Append (To_Unbounded_String (Natural'Image (Old_Mode)));
            Undo_Forward.Append (To_Unbounded_String (Natural'Image (New_Mode)));
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Set_Permissions, Undo_From, Undo_To,
               Forward => Undo_Forward);
         end;

         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;

         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Path);
      end;
   end Set_Permissions_For;

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if Bit > 8 or else not Permissions_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item     : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Mask     : constant Natural := 2 ** (8 - Bit);
         New_Mode : constant Natural :=
           (if (Item.Mode_Bits / Mask) mod 2 = 1
            then Item.Mode_Bits - Mask
            else Item.Mode_Bits + Mask);
      begin
         return Set_Permissions_For (Model, New_Mode, Settings);
      end;
   end Toggle_Permission_Bit;

   function Ownership_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is
      Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
   begin
      return Files.Model.Selected_Count (Model) = 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
        and then Files.File_System.Supports_Ownership
        and then Item.Ownership_Available
        and then Files.Model.Current_Path (Model) /= Files.File_System.Trash_Files_Directory;
   end Ownership_Editable_Selection;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if not Ownership_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item      : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Path      : constant String := To_String (Item.Full_Path);
         Old_Uid   : constant Natural := Item.Owner_Id;
         Old_Gid   : constant Natural := Item.Group_Id;
         Mutation  : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Ownership (Path, User_Id, Group_Id);
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;

         declare
            Undo_From    : Files.Types.String_Vectors.Vector;
            Undo_To      : Files.Types.String_Vectors.Vector;
            Undo_Forward : Files.Types.String_Vectors.Vector;
         begin
            Undo_From.Append (To_Unbounded_String (Path));
            Undo_To.Append
              (To_Unbounded_String
                 (Ada.Strings.Fixed.Trim (Natural'Image (Old_Uid), Ada.Strings.Both)
                  & " "
                  & Ada.Strings.Fixed.Trim (Natural'Image (Old_Gid), Ada.Strings.Both)));
            Undo_Forward.Append
              (To_Unbounded_String
                 (Ada.Strings.Fixed.Trim (Natural'Image (User_Id), Ada.Strings.Both)
                  & " "
                  & Ada.Strings.Fixed.Trim (Natural'Image (Group_Id), Ada.Strings.Both)));
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Set_Ownership, Undo_From, Undo_To,
               Forward => Undo_Forward);
         end;

         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;

         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Path);
      end;
   end Set_Ownership_For;

end Metadata;
