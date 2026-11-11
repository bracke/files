with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  A copy of a file Windows encrypts (EFS) is encrypted from its creation,
   --  so its bytes never reach the disk in the clear -- in a copy, and in a
   --  move to another volume, which copies. A copied encrypted folder is
   --  encrypted too, and so is what it holds.
   procedure Test_Copy_Encrypted_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Encrypt_Native (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_encrypt";
      function Is_Encrypted_Native (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_is_encrypted";
      Source   : constant String := Join (Root, "secret.txt");
      Folder   : constant String := Join (Root, "secrets");
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Mutation : Files.File_System.Mutation_Result;

      procedure Encrypt (Path : String) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Encrypt_Native (Name'Address) = 1, "encrypt the fixture with EFS: " & Path);
      end Encrypt;

      function Encrypted (Path : String) return Boolean is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         return Is_Encrypted_Native (Name'Address) = 1;
      end Encrypted;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Files_Suite.Support.Skip ("Test_Copy_Encrypted_File", "EFS encryption is Windows'");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Source, "secret bytes");
      Ada.Directories.Create_Directory (Folder);
      Write_Binary_File (Join (Folder, "inside"), "inner bytes");
      Encrypt (Source);
      Encrypt (Folder);
      Encrypt (Join (Folder, "inside"));
      Assert (Encrypted (Source) and then Encrypted (Folder), "the fixtures are encrypted");

      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "secret-copy.txt"));
      Assert (Mutation.Success, "copy an encrypted file: " & To_String (Mutation.Error_Key));
      Assert (File_Has_Bytes (Join (Root, "secret-copy.txt"), "secret bytes"), "the copy holds the file's bytes");
      Assert (Encrypted (Join (Root, "secret-copy.txt")), "the copy is encrypted, not decrypted");

      Mutation := Files.File_System.Copy_Tree (Folder, Join (Root, "secrets-copy"));
      Assert (Mutation.Success, "copy an encrypted folder: " & To_String (Mutation.Error_Key));
      Assert
        (Encrypted (Join (Root, "secrets-copy")) and then Encrypted (Join (Root, "secrets-copy/inside"))
           and then File_Has_Bytes (Join (Root, "secrets-copy/inside"), "inner bytes"),
         "the copied folder and the file in it are encrypted");

      Remote.Create ("files-test-encrypted-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Copy_Encrypted_File", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Source, Join (Remote.Path, "moved.txt"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source),
              "move an encrypted file to another volume: " & To_String (Mutation.Error_Key));
      Assert
        (Encrypted (Join (Remote.Path, "moved.txt"))
           and then File_Has_Bytes (Join (Remote.Path, "moved.txt"), "secret bytes"),
         "the moved file is still encrypted");
   end Test_Copy_Encrypted_File;
