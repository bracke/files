with Files.Operations;
with Files.Foreground_Jobs;
with Files.Window_Polls;
with Files.File_System;
with Files.Model.Testing;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;

with Files.Paste;
with Files.Model.Selection;

with Files_Suite.Support.Timing;

with Files_Suite.Support.Disk;

package body Files_Suite.Support.Models is
   use Files_Suite.Support.Timing;

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   use Files_Suite.Support.Disk;
   function Click_Action
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive := 20)
      return Files.Events.Input_Action
   is (Files.Events.Translate_Click
         (Snapshot,
          Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height, Line_Height),
          X, Y, Width, Height, Activate, Modifiers, Line_Height));

   procedure Run_Command
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
   is
      Result : constant Files.Controller.Controller_Result :=
        Files.Controller.Execute_Non_Settings_Command (Id, Model, Files.Settings.Default_Settings);
      pragma Unreferenced (Result);
   begin
      null;
   end Run_Command;

   function Sample_Items return Files.Items.Item_Vectors.Vector is
      Items : Files.Items.Item_Vectors.Vector;
   begin
      Items.Append (Files.File_System.Make_Item (Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item (Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item (Root, "Gamma.md", Files.Types.Regular_File_Item, "text/markdown"));
      return Items;
   end Sample_Items;

   function Sample_Model return Files.Model.Window_Model is
      Model : Files.Model.Window_Model;
   begin
      Files.Model.Initialize
        (Model,
         Directory_Path    => Root,
         Items             => Sample_Items,
         Home_Path         => "/home/test",
         Default_View_Mode => Files.Types.Small_Icons);
      return Model;
   end Sample_Model;

   procedure Select_Name
     (Model : in out Files.Model.Window_Model;
      Name  : String)
   is
      Selected : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Name);
      pragma Unreferenced (Selected);
   begin
      null;
   end Select_Name;

   function Finish_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result
   is
      Result : Files.Operation_Results.Operation_Result;
   begin
      for Attempt in Polling loop
         Result := Files.Foreground_Jobs.Advance (Model, Settings, 1);
         exit when not Files.Model.Foreground_Job_Is_Active (Model);
      end loop;
      AUnit.Assertions.Assert
        (not Files.Model.Foreground_Job_Is_Active (Model), "the paste execution finishes");
      return Result;
   end Finish_Paste;

   procedure Drain_Folder_Sizes (Model : in out Files.Model.Window_Model) is
   begin
      for Attempt in Polling loop
         Files.Window_Polls.Poll_Folder_Sizes (Model);
         exit when not Files.Model.Testing.Folder_Scan_Is_Active (Model);
      end loop;
      Assert (not Files.Model.Testing.Folder_Scan_Is_Active (Model), "the background folder-size walks finish");
   end Drain_Folder_Sizes;
   function Describe (Extra : Files.Extra_Info.Info) return String is
      use Files.Extra_Info;
      V : constant String := Ada.Strings.Unbounded.To_String (Extra.Value);
      S : constant String := Ada.Strings.Unbounded.To_String (Extra.Subject);
      N : constant String := Files.Types.Natural_Text (Extra.Count) & (if Extra.Capped then "+" else "");
   begin
      case Extra.Of_Kind is
         when None              => return "";
         when Directory_Count   => return "directory.count|" & N;
         when Executable_Format => return "executable.format|" & V;
         when Symlink_Target    => return "symlink.target|" & V;
         when Text_Lines        => return S & ".lines_encoding|" & N & "|" & V;
         when Image_Dimensions  =>
            return "image.dimensions|"
              & Files.Types.Natural_Text (Extra.Width) & "x" & Files.Types.Natural_Text (Extra.Height);
         when Document_Kind     => return "document.kind|" & V;
         when Pdf_Pages         => return "document.pdf.pages|" & N;
         when Archive_Format    => return "archive.format|" & V;
         when Archive_Entries   => return "archive." & S & ".entries|" & N;
         when Office_Entries    => return "office." & S & ".entries|" & N;
         when Media_Kind        => return "media.kind|" & V;
      end case;
   end Describe;

   procedure Arm_Numbered_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Src_Dir  : String;
      Dest_Dir : String;
      Count    : Positive)
   is
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      Load    : Files.File_System.Directory_Load_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Numbered_File (Src_Dir, N), "S" & Files.Types.Natural_Text (N));
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => Ada.Strings.Unbounded.To_Unbounded_String (Numbered_File (Src_Dir, N)),
               Dest_Path   => Ada.Strings.Unbounded.To_Unbounded_String (Numbered_File (Dest_Dir, N)),
               Skip        => False,
               Replaced    => False));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
   end Arm_Numbered_Paste;

   function Undo_Items
     (From           : Files.Types.String_Vectors.Vector;
      To             : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Forward        : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Identities     : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Provenance     : Files.Undo_History.Item_Provenance := Files.Undo_History.Captured)
      return Files.Undo_History.Recorded_Item_Vectors.Vector
   is
      function At_Index (Values : Files.Types.String_Vectors.Vector; Index : Positive) return Unbounded_String is
        (if Index <= Values.Last_Index then Values (Index) else Null_Unbounded_String);
   begin
      return Items : Files.Undo_History.Recorded_Item_Vectors.Vector do
         for Index in From.First_Index .. From.Last_Index loop
            Items.Append
              (Files.Undo_History.Recorded_Item'
                 (Item       =>
                    (From          => From (Index),
                     To            => At_Index (To, Index),
                     Forward       => At_Index (Forward, Index),
                     Identity      => At_Index (Identities, Index),
                     Tree_Revision => At_Index (Tree_Revisions, Index)),
                  Provenance => Provenance));
         end loop;
      end return;
   end Undo_Items;

   function Replaced_Originals
     (Trash : Files.Types.String_Vectors.Vector) return Files.Undo_History.Recorded_Original_Vectors.Vector is
   begin
      return Originals : Files.Undo_History.Recorded_Original_Vectors.Vector do
         for Path of Trash loop
            Originals.Append
              (Files.Undo_History.Recorded_Original'(Original => (Trash => Path, others => <>), others => <>));
         end loop;
      end return;
   end Replaced_Originals;

end Files_Suite.Support.Models;
