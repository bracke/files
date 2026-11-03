with Files.Items;
with Ada.Strings.Unbounded;

with Files.File_System;
with Files.File_Types;

package body Files.Commands.Status is

   use Ada.Strings.Unbounded;

   use type Files.Types.Focus_Target;

   --  Return whether at least one selected item is a recognized archive.
   function Selection_Has_Archive (Model : Files.Model.Window_Model) return Boolean is
      Found : Boolean := False;

      --  Read in place: every snapshot asks, and copying a Select All in a
      --  large folder for it cost more than the rest of the commands.
      procedure Check (Item : Files.Items.Directory_Item) is
      begin
         Found := Found or else Files.File_Types.Is_Extractable_Archive (To_String (Item.Name));
      end Check;
   begin
      Files.Model.For_Each_Selected_Item (Model, Check'Access);
      return Found;
   end Selection_Has_Archive;

   --  Return whether the model currently shows the platform trash payload
   --  directory rather than an ordinary directory.
   function In_Trash_View (Model : Files.Model.Window_Model) return Boolean is
   begin
      return Files.Model.Current_Is_Trash (Model);
   end In_Trash_View;

   function Status_Of
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Command_Status is separate;

   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean is (Status_Of (Id, Model).Enabled);

end Files.Commands.Status;
