separate (Files_Suite.Operations)
   procedure Test_Copy_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Environment : Files_Suite.Support.Environment_Guard;
      Source : constant String := Join (Root, "source.txt");
      Folder : constant String := Join (Root, "folder");
      Locked : constant String := Join (Root, "locked");
      Mutation : Files.File_System.Mutation_Result;
      Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
   begin
      Environment.Save ("XDG_DATA_HOME");
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
      Write_Binary_File (Source, "source bytes");
      Ada.Directories.Create_Directory (Folder);
      Write_Binary_File (Join (Folder, "inside.txt"), "inside bytes");
      Ada.Directories.Create_Directory (Locked);
      if not Lock_Directory (Locked) then
         Unlock_Directory (Locked);
         Files_Suite.Support.Skip ("Test_Copy_Read_Only_Cause", "a read-only directory does not refuse writes here");
         return;
      end if;
      Mutation := Files.File_System.Copy_Tree (Source, Join (Locked, "source.txt"));
      Assert (not Mutation.Success, "a read-only folder refuses a copied file");
      Assert_Equal
        (To_String (Mutation.Error_Key), "error.io.denied", "the refused file copy says permission was denied");
      Mutation := Files.File_System.Copy_Tree (Folder, Join (Locked, "folder"));
      Assert_Equal
        (To_String (Mutation.Error_Key), "error.io.denied", "the refused folder copy says permission was denied");
      for Mode in Files.File_System.Drop_Import_Mode loop
         Plans.Clear;
         Plans.Append
           (Files.File_System.Drop_Import_Plan'
              (Source_Path      => To_Unbounded_String (Source),
               Destination_Path => To_Unbounded_String (Join (Locked, "source.txt")),
               Mode             => Mode,
               Valid            => True,
               Error_Key        => Null_Unbounded_String));
         Mutation := Files.File_System.Execute_Drop_Import (Plans);
         Assert_Equal
           (To_String (Mutation.Error_Key), "error.io.denied",
            Files.File_System.Drop_Import_Mode'Image (Mode) & " into a read-only folder says permission was denied");
      end loop;
      Unlock_Directory (Locked);
      Assert (File_Has_Bytes (Source, "source bytes"),
              "refused copies and moves leave the sources and add nothing: source file kept");
      Assert (Ada.Directories.Exists (Join (Folder, "inside.txt")),
              "refused copies and moves leave the sources and add nothing: source folder kept");
      Assert (not Ada.Directories.Exists (Join (Locked, "source.txt")),
              "refused copies and moves leave the sources and add nothing: no file added");
      Assert (not Ada.Directories.Exists (Join (Locked, "folder")),
              "refused copies and moves leave the sources and add nothing: no folder added");

      --  The next copy starts afresh: the earlier refusal does not explain it.
      Mutation := Files.File_System.Copy_Tree (Join (Root, "absent.txt"), Join (Root, "copy.txt"));
      Assert_Equal (To_String (Mutation.Error_Key), "error.copy.failed", "an unrelated failure keeps the generic key");
   exception
      when others =>
         Unlock_Directory (Locked);
         raise;
   end Test_Copy_Read_Only_Cause;
