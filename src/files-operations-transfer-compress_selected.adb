separate (Files.Operations.Transfer)
   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      Input_Paths : Files.Types.String_Vectors.Vector;
      Entry_Names : Files.Types.String_Vectors.Vector;

      --  Recursively collect ordinary files under a selected entry, recording
      --  each with a directory-relative archive entry name (forward slashes).
      procedure Collect (Full : String; Entry_Name : String) is
         Search    : Ada.Directories.Search_Type;
         Started   : Boolean := False;
         Dir_Entry : Ada.Directories.Directory_Entry_Type;
      begin
         if not Ada.Directories.Exists (Full) then
            return;
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Directory then
            Ada.Directories.Start_Search
              (Search,
               Directory => Full,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => False]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     Collect
                       (Ada.Directories.Full_Name (Dir_Entry),
                        Entry_Name & "/" & Name);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Ordinary_File then
            Input_Paths.Append (To_Unbounded_String (Full));
            Entry_Names.Append (To_Unbounded_String (Entry_Name));
         end if;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
      end Collect;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      for Item of Items loop
         Collect (To_String (Item.Full_Path), To_String (Item.Name));
      end loop;

      if Input_Paths.Is_Empty then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      declare
         Extension : constant String :=
           (case Format is
               when Zip_Archive       => "zip",
               when Seven_Zip_Archive => "7z");
         Raw_Base : constant String :=
           Ada.Directories.Base_Name (To_String (Items.First_Element.Name));
         Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

         --  A directory-unique simple archive name, e.g. "report.zip" or
         --  "report (1).zip" when the first choice already exists.
         function Unique_Name return String is
         begin
            if not Ada.Directories.Exists
                     (Ada.Directories.Compose (Directory, Base, Extension))
            then
               return Base & "." & Extension;
            end if;

            for N in 1 .. 9_999 loop
               declare
                  Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
               begin
                  if not Ada.Directories.Exists
                           (Ada.Directories.Compose (Directory, Candidate, Extension))
                  then
                     return Candidate & "." & Extension;
                  end if;
               end;
            end loop;

            return Base & "." & Extension;
         end Unique_Name;

         Archive_Name : constant String := Unique_Name;
         Output_Path  : constant String := Ada.Directories.Compose (Directory, Archive_Name);
         Count        : constant Natural := Natural (Input_Paths.Length);
         Inputs       : Zlib.Text_Array (1 .. Count);
         Names        : Zlib.Text_Array (1 .. Count);
         Status       : Zlib.Status_Code;
      begin
         for I in 1 .. Count loop
            Inputs (I) := Input_Paths.Element (I);
            Names  (I) := Entry_Names.Element (I);
         end loop;

         case Format is
            when Zip_Archive =>
               Zlib.ZIP_Files (Inputs, Output_Path, Names, Status => Status);
            when Seven_Zip_Archive =>
               Zlib.Seven_Zip_Deflate_Files (Inputs, Output_Path, Names, Status => Status);
         end case;

         if Status /= Zlib.Ok then
            return Make_Result (Operation_Failed, "error.compress.failed", Directory);
         end if;

         --  Reload so the new archive appears, and select it.
         return Reload_Current_Directory (Model, Settings, Archive_Name);
      end;
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Compress_Selected;
