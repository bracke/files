with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.File_System;

package body Files.Commands.Status is

   use Ada.Strings.Unbounded;

   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;

   --  Return whether a simple file name ends, case-insensitively, in a
   --  recognized archive extension (.zip or .7z).
   function Name_Is_Archive (Name : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
        or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
   end Name_Is_Archive;

   --  Return whether at least one selected item is a recognized archive.
   function Selection_Has_Archive (Model : Files.Model.Window_Model) return Boolean is
      Items : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
   begin
      for Item of Items loop
         if Name_Is_Archive (To_String (Item.Name)) then
            return True;
         end if;
      end loop;

      return False;
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
