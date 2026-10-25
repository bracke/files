separate (Files_Suite.Model)
   procedure Test_Untitled_Name_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Dangling_Untitled : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 3.txt"));
      Write_File (Join (Root, "name-parent.txt"));
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Next_Untitled_Name (Join (Root, "name-parent.txt")),
         "untitled.txt",
         "untitled name generation falls back deterministically for non-directory probes");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Next_Untitled_Name (Root),
         "untitled 2.txt",
         "untitled name generation skips directory collisions");
      Dangling_Untitled := Create_Symlink ("missing-target", Join (Root, "untitled 2.txt"));
      if Dangling_Untitled then
         Files_Suite.Support.Assert_Equal
           (Files.File_System.Next_Untitled_Name (Root),
            "untitled 4.txt",
            "untitled name generation skips dangling-link collisions");
      end if;
      Files.Model.Initialize (Model, Root, Items, Root);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success,
         "untitled name generation creates its first temporary item (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         (if Dangling_Untitled then "untitled 4.txt" else "untitled 2.txt"),
         "create uses the first suffix without an existing directory entry");
      Files.Model.Cancel_Create_File (Model);
      declare
         function Suffix_Text (Value : Natural) return String is
            Image : constant String := Natural'Image (Value);
         begin
            if Image'Length > 0 and then Image (Image'First) = ' ' then
               return Image (Image'First + 1 .. Image'Last);
            end if;

            return Image;
         end Suffix_Text;
      begin
         for Index in 2 .. 10 loop
            Write_File (Join (Root, "untitled " & Suffix_Text (Index) & ".txt"));
         end loop;
      end;
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status, Files.Operations.Operation_Success,
         "untitled name generation creates its next temporary item (status)");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 11.txt",
         "create uses explicit spaced suffix text after single digits");
   end Test_Untitled_Name_Generation;
