separate (Files_Suite.Operations)
   procedure Test_Transfer_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "chunk-source");
      Dest   : constant String := Join (Root, "chunk-dest");
      Plans  : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Result : Files.File_System.Mutation_Result;
      Checks : Natural := 0;

      function Cancelled return Boolean is
      begin
         Checks := Checks + 1;
         if Checks = 4 then
            Assert (Ada.Directories.Size (Join (Join (Root, ".files-work-1"), "payload")) = 65_536,
                    "cancellation occurs after the first chunk has been written");
         end if;
         return Checks >= 4;
      end Cancelled;
   begin
      Reset_Root;
      Write_Binary_File (Source, [1 .. 262_144 => 'x']);
      Plans.Append
        (Files.File_System.Drop_Import_Plan'
           (Source_Path      => To_Unbounded_String (Source),
            Destination_Path => To_Unbounded_String (Dest),
            Mode             => Files.File_System.Drop_Copy,
            Valid            => True,
            Error_Key        => Null_Unbounded_String));
      Result := Files.File_System.Execute_Drop_Import (Plans, Cancelled'Unrestricted_Access);
      Assert (not Result.Success and then Checks >= 4, "cancellation interrupts a file after copying begins");
      Assert (not Ada.Directories.Exists (Dest), "cancellation removes the incomplete destination");
      Assert (Ada.Directories.Size (Source) = 262_144, "the complete source survives cancellation");

      --  A destination created after planning is someone else's data.
      Write_Binary_File (Dest, "keep");
      Result := Files.File_System.Execute_Drop_Import (Plans);
      Assert (not Result.Success, "a late destination collision fails");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Dest),
         "keep",
         "collision cleanup never removes unrelated data");
      Plans.Clear;
      Plans.Append
        (Files.File_System.Drop_Import_Plan'
           (Source_Path      => To_Unbounded_String (Source),
            Destination_Path => To_Unbounded_String (Source),
            Mode             => Files.File_System.Drop_Copy,
            Valid            => True,
            Error_Key        => Null_Unbounded_String));
      Result := Files.File_System.Execute_Drop_Import (Plans);
      Assert (not Result.Success, "copying onto the source is refused");
      Assert (Ada.Directories.Size (Source) = 262_144, "a self-copy never truncates or deletes its source");

      Ada.Directories.Delete_File (Dest);
      Plans.Clear;
      Plans.Append
        (Files.File_System.Drop_Import_Plan'
           (Source_Path      => To_Unbounded_String (Source),
            Destination_Path => To_Unbounded_String (Dest),
            Mode             => Files.File_System.Drop_Move,
            Valid            => True,
            Error_Key        => Null_Unbounded_String));
      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Result := Files.File_System.Execute_Drop_Import (Plans);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Files.File_Identities.Testing.Set_Unavailable (False);
      Assert (not Result.Success, "a move without a recoverable identity is refused before publication: refused");
      Assert
        (Ada.Directories.Exists (Source),
         "a move without a recoverable identity is refused before publication: source kept");
      Assert
        (not Ada.Directories.Exists (Dest),
         "a move without a recoverable identity is refused before publication: destination not created");
   end Test_Transfer_Cancellation;
