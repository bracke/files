with Ada.Characters.Handling;
with Hostkit.Fs;
with Hostkit.Trash;
separate (Files_Suite.Operations)
   procedure Test_Recycle_Bin_Trash_View (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      --  Unique per run: the Recycle Bin is the user's own and outlives the
      --  test, so an item left by an earlier run must not be taken for ours.
      Stamp    : constant String :=
        Ada.Strings.Fixed.Trim (Integer'Image (Integer (Ada.Calendar.Seconds (Ada.Calendar.Clock))), Ada.Strings.Both);
      Name     : constant String := "recycle-bin-view-" & Stamp & ".txt";
      Folder   : constant String := "recycle-bin-folder-" & Stamp;
      Source   : constant String := Join (Root, Name);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Trashed  : Files.Types.UString;

      --  The same place, whichever separators, letter case or short (8.3)
      --  names it was given in: the shell records the long form.
      function Same_Path (Left, Right : String) return Boolean is
         function Plain (Path : String) return String is
            Result : String := Ada.Characters.Handling.To_Lower (Path);
         begin
            for Char of Result loop
               if Char = '/' then
                  Char := '\';
               end if;
            end loop;
            return Result;
         end Plain;

         function Split (Path : String) return Natural is
         begin
            for Index in reverse Path'Range loop
               if Path (Index) in '/' | '\' then
                  return Index;
               end if;
            end loop;
            return 0;
         end Split;

         --  The folder, resolved where it still exists.
         function Folder (Path : String) return String is
            At_Split : constant Natural := Split (Path);
            Text     : constant String := (if At_Split = 0 then "" else Path (Path'First .. At_Split - 1));
            Real     : constant String := (if Text = "" then "" else Hostkit.Fs.Real_Path (Text));
         begin
            return Plain (if Real = "" then Text else Real);
         end Folder;
      begin
         return Plain (Left) = Plain (Right)
           or else (Folder (Left) = Folder (Right)
                    and then Plain (Left (Split (Left) + 1 .. Left'Last))
                               = Plain (Right (Split (Right) + 1 .. Right'Last)));
      end Same_Path;

      --  The trash view's item listed as Item_Name, or "".
      function Listed (Item_Name : String) return String is
         Trash : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      begin
         for Item of Trash.Items loop
            if To_String (Item.Name) = Item_Name then
               return To_String (Item.Full_Path);
            end if;
         end loop;
         return "";
      end Listed;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Files_Suite.Support.Skip ("Test_Recycle_Bin_Trash_View", "needs the Windows Recycle Bin");
         return;
      end if;
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Reset_Root;
      Write_File (Source, "recycled");

      --  Delete moves it to the Recycle Bin and records an Undo.
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, Name);
      Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "Delete moves the item to the Recycle Bin");
      Assert (not Path_Exists (Source), "the item is gone from its folder");
      Assert (Files.Model.Undo_Available (Model), "moving to the Recycle Bin records an Undo");

      --  "Go to Trash" shows the Recycle Bin, the item under its own name.
      Assert (Files.File_System.Trash_Files_Directory /= "", "the Recycle Bin is the trash view");
      declare
         Recycled : constant String := Listed (Name);
      begin
         Assert (Recycled /= "", "the trash view lists the item under its original name");
         Assert (Hostkit.Trash.Is_Recycled_Item (Recycled), "as the $R item the shell made; was " & Recycled);
         Assert
           (Same_Path (Files.File_System.Trash_Original_Path (Recycled), Source),
            "whose $I record names where it came from; was " & Files.File_System.Trash_Original_Path (Recycled));
         Assert (Files.File_System.Is_Volume_Trash_Item (Recycled), "and counts as an item of the trash");

         --  Undo puts it back from there.
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "Undo of the move to the Recycle Bin succeeds");
         Assert (File_Has_Bytes (Source, "recycled"), "Undo restores the item where it was");
         Assert (not Path_Exists (Recycled), "and it is no longer in the bin");
      end;

      --  Restore from the trash view.
      Mutation := Files.File_System.Move_To_Trash (Source, Trashed);
      Assert (Mutation.Success, "the item goes to the Recycle Bin again; error was " & To_String (Mutation.Error_Key));
      Assert (Path_Exists (To_String (Trashed)), "and the trashed path names it there");
      Step := Files.Operations.Navigate_Trash (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Navigated, "Go to Trash opens the Recycle Bin");
      Assert (Files.Model.Current_Is_Trash (Model), "the view knows it is the trash");
      Select_Name (Model, Name);
      Step := Complete_Operation (Model, Settings, Files.Operations.Restore_Selected_From_Trash (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "Restore puts the selected item back");
      Assert (File_Has_Bytes (Source, "recycled"), "restored where it was, as it was");
      Assert (not Path_Exists (To_String (Trashed)), "and gone from the bin");

      --  Restore never replaces what took the item's place.
      Mutation := Files.File_System.Move_To_Trash (Source, Trashed);
      Assert (Mutation.Success, "the item goes to the Recycle Bin a third time");
      Write_File (Source, "newcomer");
      Mutation := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Assert (not Mutation.Success, "a restore onto a taken name is refused");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key), "error.trash.restore_exists", "and says the name is taken");
      Assert (File_Has_Bytes (Source, "newcomer"), "the newcomer is untouched");
      Assert (Path_Exists (To_String (Trashed)), "the item stays in the bin");

      --  Deleting from the bin -- what Empty Trash does to each item, which
      --  this does not run: it would empty the user's whole Recycle Bin.
      Mutation := Files.File_System.Delete_Trashed_Item (To_String (Trashed));
      Assert (Mutation.Success, "an item is deleted from the bin; error was " & To_String (Mutation.Error_Key));
      Assert (not Path_Exists (To_String (Trashed)), "the item is gone");
      Assert (Listed (Name) = "", "and the trash view no longer lists it");
      Assert (File_Has_Bytes (Source, "newcomer"), "deleting from the bin touches nothing outside it");

      --  A folder goes in whole and is deleted from the bin whole.
      Ada.Directories.Create_Directory (Join (Root, Folder));
      Write_File (Join (Join (Root, Folder), "inside.txt"), "inside");
      Mutation := Files.File_System.Move_To_Trash (Join (Root, Folder), Trashed);
      Assert (Mutation.Success, "a folder goes to the Recycle Bin");
      Assert (Same_Path (Listed (Folder), To_String (Trashed)), "and is listed under its own name");
      Assert (Path_Exists (Join (To_String (Trashed), "inside.txt")), "with what it holds");
      Mutation := Files.File_System.Delete_Trashed_Item (To_String (Trashed));
      Assert
        (Mutation.Success and then not Path_Exists (To_String (Trashed)), "a folder is deleted from the bin whole");
   end Test_Recycle_Bin_Trash_View;
