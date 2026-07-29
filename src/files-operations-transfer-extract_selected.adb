separate (Files.Operations.Transfer)
   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Extracted_Any : Boolean := False;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Treat a name ending (case-insensitively) in .zip or .7z as an archive.
      function Name_Is_Archive (Name : String) return Boolean is
         Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
      begin
         return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
           or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
      end Name_Is_Archive;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Item_Name : constant String := To_String (Item.Name);
            Full_Path : constant String := To_String (Item.Full_Path);
         begin
            if Name_Is_Archive (Item_Name) then
               declare
                  Raw_Base : constant String := Ada.Directories.Base_Name (Item_Name);
                  Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

                  --  A directory-unique destination folder name, e.g. "report"
                  --  or "report (1)" when the first choice already exists.
                  function Unique_Name return String is
                  begin
                     if not Ada.Directories.Exists (Ada.Directories.Compose (Directory, Base)) then
                        return Base;
                     end if;

                     for N in 1 .. 9_999 loop
                        declare
                           Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
                        begin
                           if not Ada.Directories.Exists (Ada.Directories.Compose (Directory, Candidate)) then
                              return Candidate;
                           end if;
                        end;
                     end loop;

                     return Base;
                  end Unique_Name;

                  Dest_Name : constant String := Unique_Name;
                  Dest_Dir  : constant String := Ada.Directories.Compose (Directory, Dest_Name);
                  Status    : Zlib.Status_Code;
               begin
                  Ada.Directories.Create_Directory (Dest_Dir);
                  Zlib.Extract_Archive_File_To_Directory (Full_Path, Dest_Dir, "", Status);

                  if Status /= Zlib.Ok then
                     return Make_Result (Operation_Failed, "error.extract.failed", Directory);
                  end if;

                  if not Extracted_Any then
                     First_Created := To_Unbounded_String (Dest_Name);
                     Extracted_Any := True;
                  end if;
               end;
            end if;
         end;
      end loop;

      if not Extracted_Any then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      --  Reload so the new directories appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
   end Extract_Selected;
