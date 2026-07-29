separate (Files.File_System.Directory)
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result
   is
      Search : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Items  : Item_Vectors.Vector;
      Normalized_Path : Unbounded_String;
      Started : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Items     => Items,
            Error_Key => To_Unbounded_String ("error.directory.load"));
      end if;

      Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         begin
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         exception
            when others =>
               --  The enumeration itself failed, not one entry within it -- a file
               --  that vanished mid-scan, typically. There is no way to step past
               --  that and be sure of advancing, so stop and keep what we have: a
               --  directory listed as far as we got beats one that will not open.
               exit;
         end;

         --  An entry we cannot even name is skipped, not fatal. Naming it sits
         --  outside the guard below, so it used to fall through to the handler at
         --  the bottom and fail the whole load -- which is why C:\ loaded only when
         --  nothing in it happened to be unreadable at that moment.
         begin
            declare
               Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            begin
               if Name /= "."
                 and then Name /= ".."
                 and then (Settings.Show_Hidden_Files or else Name (Name'First) /= '.')
               then
                  --  One entry we cannot inspect must not cost us the directory. It
                  --  used to: anything raised here fell through to the handler below
                  --  and the whole load failed, so a single locked entry made the
                  --  directory unopenable. On Linux you rarely meet one; C:\ has
                  --  several -- System Volume Information, pagefile.sys, DumpStack.log
                  --  -- so the drive root, the one directory a Windows user starts
                  --  from, could not be listed at all.
                  --
                  --  An entry whose kind we cannot read is still an entry the user can
                  --  see, so keep it and say only what we know, rather than hiding it.
                  begin
                     declare
                        Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
                        Kind : constant Files.Types.Item_Kind := Kind_From_Directory_Entry (Dir_Entry);
                     begin
                        Items.Append
                          (Item_For_Path (Full, Name, To_String (Normalized_Path), Kind, Settings));
                     end;
                  exception
                     when others =>
                        begin
                           Items.Append
                             (Item_For_Path
                                (Join_Path (To_String (Normalized_Path), Name),
                                 Name,
                                 To_String (Normalized_Path),
                                 Files.Types.Other_Item,
                                 Settings));
                        exception
                           when others =>
                              null;
                        end;
                  end;
               end if;
            end;
            exception
               when others =>
                  null;
         end;
      end loop;

         Safe_End_Search (Search, Started);

         Sort_Items (Items, Settings.Sort_Field_Value, Settings.Sort_Ascending);

         return
           (Success   => True,
            Path      => Normalized_Path,
            Items     => Items,
            Error_Key => Null_Unbounded_String);
      exception
         when others =>
            Safe_End_Search (Search, Started);
            return
              (Success   => False,
               Path      => To_Unbounded_String (Path),
               Items     => Items,
               Error_Key => To_Unbounded_String ("error.directory.load"));
   end Load_Directory;
