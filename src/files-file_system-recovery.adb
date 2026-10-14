with Files.File_Identities;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;
with Hostkit.Durability;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.Bounded_Streams;
with Files.Exclusive_Streams;
with Files.Lease_Streams;
with Files.Private_Directories;

package body Files.File_System.Recovery is
   use Ada.Strings.Unbounded;
   use Files.File_System.Support;
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Files.Private_Directories.Create_Result;
   use type Hostkit.Durability.Outcome;
   use type Hostkit.Lease_Files.Open_Outcome;

   Owner_Name : constant String := ".files-recovery-owner";
   Owner_Magic : constant String := "files-recovery-v1";
   Registry_Magic : constant String := "files-recovery-registry-v1";
   Max_Header_Length : constant := 128;
   Max_Path_Length : constant := 32 * 1024;
   Max_Identity_Length : constant := 1024;
   Max_Record_Bytes : constant :=
     Max_Header_Length + Max_Path_Length + Max_Identity_Length + 3 * 16;

   function Record_Is_Regular
     (Path : String; Maximum : Natural := Max_Record_Bytes) return Boolean
   is
   begin
      return not Hostkit.Fs.Is_Link (Path)
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File
        and then Ada.Directories.Size (Path) <= Ada.Directories.File_Size (Maximum);
   exception
      when others => return False;
   end Record_Is_Regular;

   function Valid_Absolute_Path (Path : String) return Boolean is
   begin
      if Path = "" then
         return False;
      end if;
      for Item of Path loop
         if Item = Character'Val (0) then
            return False;
         end if;
      end loop;
      return GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others => return False;
   end Valid_Absolute_Path;

   procedure Write_Bounded
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Maximum : Natural)
   is
   begin
      if Value'Length > Maximum then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Value);
   end Write_Bounded;

   function Registry_Data_Directory return String is
   begin
      if Ada.Environment_Variables.Exists ("FILES_TEST_TEMP") then
         declare
            Root : constant String :=
              Ada.Environment_Variables.Value ("FILES_TEST_TEMP");
         begin
            return
              (if Valid_Absolute_Path (Root) then Join_Path (Root, "data")
               else "");
         end;
      end if;
      declare
         Root : constant String := Hostkit.Fs.Application_Data_Directory;
      begin
         return (if Valid_Absolute_Path (Root) then Root else "");
      end;
   exception
      when others => return "";
   end Registry_Data_Directory;

   function Registry_Root (Create : Boolean) return String is
      Data : constant String := Registry_Data_Directory;
      App  : constant String := (if Data = "" then "" else Join_Path (Data, "files"));
      Root : constant String := (if App = "" then "" else Join_Path (App, "recovery-index"));

      procedure Ensure_Directory (Path : String; Parents : Boolean := False) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            raise Ada.Directories.Use_Error;
         elsif Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) /= Ada.Directories.Directory then
               raise Ada.Directories.Use_Error;
            end if;
         elsif Parents then
            Ada.Directories.Create_Path (Path);
         else
            Files.Private_Directories.Create (Path);
         end if;
      end Ensure_Directory;
   begin
      if Root = "" then
         return "";
      end if;
      if Create then
         Ensure_Directory (Data, Parents => True);
         Ensure_Directory (App);
         Ensure_Directory (Root);
      elsif not Ada.Directories.Exists (Root)
        or else Hostkit.Fs.Is_Link (Root)
        or else Ada.Directories.Kind (Root) /= Ada.Directories.Directory
      then
         return "";
      end if;
      return Root;
   exception
      when others => return "";
   end Registry_Root;

   function Read_Owner
     (Stage : String; Original, Identity : out UString) return Boolean
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Magic : UString;
      Record_Path : constant String := Join_Path (Stage, Owner_Name);
   begin
      Original := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      if not Record_Is_Regular (Record_Path) then
         return False;
      end if;
      if Files.Lease_Streams.Open (Record_Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) > Max_Record_Bytes
      then
         Files.Lease_Streams.Release (Input);
         return False;
      end if;
      Magic := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Header_Length));
      Original := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Path_Length));
      Identity := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Identity_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return To_String (Magic) = Owner_Magic
        and then Valid_Absolute_Path (To_String (Original))
        and then
          (Length (Identity) = 0
           or else Files.File_Identities.Token (Stage) = To_String (Identity));
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         Original := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         return False;
   end Read_Owner;

   procedure Write_Owner (Stage, Original : String) is
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      if not Valid_Absolute_Path (Original) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Exclusive_Streams.Create (File, Join_Path (Stage, Owner_Name));
      Write_Bounded
        (File'Access, Owner_Magic, Max_Header_Length);
      Write_Bounded
        (File'Access, Original, Max_Path_Length);
      Write_Bounded
        (File'Access, Files.File_Identities.Token (Stage), Max_Identity_Length);
      Files.Exclusive_Streams.Close (File);
      if Hostkit.Durability.Sync_File (Join_Path (Stage, Owner_Name)) /=
        Hostkit.Durability.Synced
      then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others => Files.Exclusive_Streams.Close_Safely (File); raise;
   end Write_Owner;

   function Contains_Only_Owned_Entries (Stage : String) return Boolean is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Open   : Boolean := False;
   begin
      Ada.Directories.Start_Search (Search, Stage, "*");
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name not in "." | ".." | "payload" | "original" | "mode" | Owner_Name then
               Ada.Directories.End_Search (Search);
               return False;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return True;
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
         return False;
   end Contains_Only_Owned_Entries;

   function Read_Registry_Record
     (Directory : String; Payload, Identity : out UString) return Boolean
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Magic : UString;
      Record_Path : constant String := Join_Path (Directory, "record");
   begin
      Payload := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      if Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else not Record_Is_Regular (Record_Path)
      then
         return False;
      end if;
      if Files.Lease_Streams.Open (Record_Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) > Max_Record_Bytes
      then
         Files.Lease_Streams.Release (Input);
         return False;
      end if;
      Magic := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Header_Length));
      Payload := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Path_Length));
      Identity := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Identity_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return To_String (Magic) = Registry_Magic
        and then Valid_Absolute_Path (To_String (Payload));
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         Payload := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         return False;
   end Read_Registry_Record;

   procedure Delete_Registry_Record (Directory : String) is
      Root : constant String := Registry_Root (Create => False);
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Open : Boolean := False;
      Count : Natural := 0;
   begin
      if Root = ""
        or else Ada.Directories.Containing_Directory (Directory) /= Root
        or else not Starts_With (Ada.Directories.Simple_Name (Directory), ".files-recovery-")
        or else Hostkit.Fs.Is_Link (Directory)
      then
         return;
      end if;
      Ada.Directories.Start_Search (Search, Directory, "*");
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         if Ada.Directories.Simple_Name (Item) = "record" then
            Count := Count + 1;
         elsif Ada.Directories.Simple_Name (Item) not in "." | ".." then
            Ada.Directories.End_Search (Search);
            return;
         end if;
      end loop;
      Ada.Directories.End_Search (Search);
      Open := False;
      if Count = 1 then
         Delete_Owned_Tree (Directory);
      end if;
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
   end Delete_Registry_Record;

   function Register (Payload : String) return String is
      Root : constant String := Registry_Root (Create => True);
      Directory : UString;
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      if Root = "" or else not Valid_Absolute_Path (Payload) then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Candidate : constant String :=
              Join_Path (Root, ".files-recovery-" & Image_No_Space (N));
         begin
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               goto Continue;
            end if;
            Directory := To_Unbounded_String (Candidate);
            exit;
            <<Continue>>
         end;
      end loop;
      if Length (Directory) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Exclusive_Streams.Create
        (File, Join_Path (To_String (Directory), "record"));
      Write_Bounded
        (File'Access, Registry_Magic, Max_Header_Length);
      Write_Bounded
        (File'Access, Payload, Max_Path_Length);
      Write_Bounded
        (File'Access,
         Files.File_Identities.Token (Ada.Directories.Containing_Directory (Payload)),
         Max_Identity_Length);
      Files.Exclusive_Streams.Close (File);
      if Hostkit.Durability.Sync_File (Join_Path (To_String (Directory), "record")) /=
          Hostkit.Durability.Synced
        or else Hostkit.Durability.Sync_Directory (To_String (Directory)) =
          Hostkit.Durability.Failed
        or else Hostkit.Durability.Sync_Directory (Root) = Hostkit.Durability.Failed
      then
         raise Ada.Directories.Use_Error;
      end if;
      return To_String (Directory);
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         if Length (Directory) > 0 then
            Delete_Registry_Record (To_String (Directory));
         end if;
         raise;
   end Register;

   procedure Unregister (Payload : String) is
      Root : constant String := Registry_Root (Create => False);
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Open : Boolean := False;
   begin
      if Root = "" then
         return;
      end if;
      Ada.Directories.Start_Search (Search, Root, ".files-recovery-*",
        [Ada.Directories.Directory => True, others => False]);
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Recorded, Identity : UString;
            Directory : constant String := Ada.Directories.Full_Name (Item);
         begin
            if Read_Registry_Record (Directory, Recorded, Identity)
              and then To_String (Recorded) = Payload
            then
               Delete_Registry_Record (Directory);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
   end Unregister;

   function Remove_Move_Source
     (Path : String; Expected : Support.Source_Snapshot) return Mutation_Result is
      use type Files.Types.String_Vectors.Vector;
      use type Support.Source_Snapshot;
      Backup : UString;
      Committed : Boolean := False;
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
   begin
      if Expected.Entries.Is_Empty or else Snapshot (Path) /= Expected then
         return Failed;
      end if;
      declare
         Saved : constant Mutation_Result := Preserve (Path, Backup);
      begin
         if not Saved.Success then
            return Saved;
         end if;
      end;
      --  Check the private source too. Its rename changes the root's ctime;
      --  descendants and all identities, sizes, modes and mtimes must match.
      begin
         if Snapshot (To_String (Backup)).Entries /= Expected.Entries then
            raise Ada.Directories.Use_Error;
         end if;
      exception
         when others =>
            declare
               Restored : constant Mutation_Result := Restore (To_String (Backup));
               pragma Unreferenced (Restored);
            begin
               return Failed;
            end;
      end;
      Committed := True;
      --  Once the source pathname is vacated the move is committed. Refused
      --  cleanup leaves a hidden backup; it cannot invalidate the complete
      --  destination or expose a partly deleted tree at the source pathname.
      declare
         Removed : constant Mutation_Result := Discard (To_String (Backup));
         pragma Unreferenced (Removed);
      begin
         null;
      exception
         when others => null;
      end;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return (Success => Committed,
                 Error_Key => (if Committed then Null_Unbounded_String else To_Unbounded_String ("error.drop.failed")));
   end Remove_Move_Source;

   function Recognizes (Path : String) return Boolean is
      Parent : constant String := Ada.Directories.Containing_Directory (Path);
      Original, Identity : UString;
   begin
      return Ada.Directories.Simple_Name (Path) = "payload"
        and then Starts_With (Ada.Directories.Simple_Name (Parent), ".files-recovery-")
        and then not Hostkit.Fs.Is_Link (Parent)
        and then Ada.Directories.Exists (Parent)
        and then Ada.Directories.Kind (Parent) = Ada.Directories.Directory
        and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path))
        and then Read_Owner (Parent, Original, Identity);
   exception
      when others => return False;
   end Recognizes;

   function Discard (Path : String) return Mutation_Result is
      Parent : constant String := Ada.Directories.Containing_Directory (Path);
   begin
      if not Recognizes (Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      if not Contains_Only_Owned_Entries (Parent) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      Delete_Owned_Tree (Parent);
      if Ada.Directories.Exists (Parent) or else Hostkit.Fs.Is_Link (Parent) then
         raise Ada.Directories.Use_Error;
      end if;
      Unregister (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Discard;

   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result is
      Original : constant String := GNAT.OS_Lib.Normalize_Pathname (Path, Resolve_Links => False);
      Parent   : constant String := Ada.Directories.Containing_Directory (Original);
      Stage    : UString;
      Registry_Entry : UString;
      File     : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      Backup := Null_Unbounded_String;
      if not Valid_Absolute_Path (Original) then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Candidate : constant String := Join_Path (Parent, ".files-recovery-" & Image_No_Space (N));
         begin
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               goto Continue;
            end if;
            Stage := To_Unbounded_String (Candidate);
            exit;
            <<Continue>>
         end;
      end loop;
      if Length (Stage) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Exclusive_Streams.Create
        (File, Join_Path (To_String (Stage), "original"));
      Write_Bounded
        (File'Access, Original, Max_Path_Length);
      Files.Exclusive_Streams.Close (File);
      if Hostkit.Durability.Sync_File (Join_Path (To_String (Stage), "original")) /=
        Hostkit.Durability.Synced
      then
         raise Ada.Directories.Use_Error;
      end if;
      Write_Owner (To_String (Stage), Original);
      Registry_Entry := To_Unbounded_String
        (Register (Join_Path (To_String (Stage), "payload")));
      if not Hostkit.Fs.Is_Link (Path) and then Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         declare
            Available : Boolean;
            Mode : constant Natural := Permission_Bits_Of (Path, Available);
         begin
            if Available and then (Mode / 8#200#) mod 2 = 0 then
               Files.Exclusive_Streams.Create
                 (File, Join_Path (To_String (Stage), "mode"));
               Natural'Output (File'Access, Mode);
               Write_Bounded
                 (File'Access,
                  Files.File_Identities.Token (Path), Max_Identity_Length);
               Files.Exclusive_Streams.Close (File);
               if Hostkit.Durability.Sync_File (Join_Path (To_String (Stage), "mode")) /=
                 Hostkit.Durability.Synced
               then
                  raise Ada.Directories.Use_Error;
               end if;
            end if;
         end;
      end if;
      if Hostkit.Durability.Sync_Directory (To_String (Stage)) = Hostkit.Durability.Failed
        or else Hostkit.Durability.Sync_Directory (Parent) = Hostkit.Durability.Failed
      then
         raise Ada.Directories.Use_Error;
      end if;
      if not Support.Move_No_Replace (Path, Join_Path (To_String (Stage), "payload")) then
         --  The backup is beside the original, so a refused rename must leave
         --  the original in place rather than starting a destructive fallback.
         raise Ada.Directories.Use_Error;
      end if;
      Backup := To_Unbounded_String (Join_Path (To_String (Stage), "payload"));
      if Hostkit.Durability.Sync_Directory (To_String (Stage)) = Hostkit.Durability.Failed
        or else Hostkit.Durability.Sync_Directory (Parent) = Hostkit.Durability.Failed
      then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         if Length (Stage) > 0 and then Length (Backup) = 0 then
            if Ada.Directories.Exists (Join_Path (To_String (Stage), "payload"))
              or else Hostkit.Fs.Is_Link (Join_Path (To_String (Stage), "payload"))
            then
               Backup := To_Unbounded_String (Join_Path (To_String (Stage), "payload"));
               return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
            end if;
            begin
               Delete_Tree (To_String (Stage));
            exception
               when others => null;
            end;
            if Length (Registry_Entry) > 0 then
               Delete_Registry_Record (To_String (Registry_Entry));
            end if;
         end if;
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Preserve;

   function Original_Path (Path : String) return String is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Target : UString;
      Identity : UString;
      Record_Path : constant String :=
        Join_Path (Ada.Directories.Containing_Directory (Path), "original");
   begin
      if Read_Owner (Ada.Directories.Containing_Directory (Path), Target, Identity) then
         return To_String (Target);
      end if;
      if not Record_Is_Regular
        (Record_Path, Max_Path_Length + 16)
      then
         return "";
      end if;
      if Files.Lease_Streams.Open (Record_Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) > Max_Path_Length + 16
      then
         Files.Lease_Streams.Release (Input);
         return "";
      end if;
      Target := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Path_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return
        (if Valid_Absolute_Path (To_String (Target)) then
            To_String (Target)
         else "");
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         return "";
   end Original_Path;

   function Registered_Payloads return Files.Types.String_Vectors.Vector is
      Root : constant String := Registry_Root (Create => False);
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Open : Boolean := False;
      Result : Files.Types.String_Vectors.Vector;
   begin
      if Root = "" then
         return Result;
      end if;
      Ada.Directories.Start_Search (Search, Root, ".files-recovery-*",
        [Ada.Directories.Directory => True, others => False]);
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Payload, Expected : UString;
            Directory : constant String := Ada.Directories.Full_Name (Item);
         begin
            if Read_Registry_Record (Directory, Payload, Expected)
              and then Recognizes (To_String (Payload))
              and then
                (Length (Expected) = 0
                 or else Files.File_Identities.Token
                   (Ada.Directories.Containing_Directory (To_String (Payload))) =
                     To_String (Expected))
            then
               Result.Append (Payload);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return Result;
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
         return Result;
   end Registered_Payloads;

   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result is
      Parent : constant String := Ada.Directories.Containing_Directory (Path);
      Target : UString;
   begin
      if not Recognizes (Path) or else not Contains_Only_Owned_Entries (Parent) then
         return
           (Success => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      Target := To_Unbounded_String
        (if Expected_Original /= "" then Expected_Original else Original_Path (Path));
      if not Valid_Absolute_Path (To_String (Target)) then
         raise Ada.Directories.Use_Error;
      end if;
      if Ada.Directories.Exists (To_String (Target)) or else Hostkit.Fs.Is_Link (To_String (Target)) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;
      --  A failed post-rename permission restoration can leave the private
      --  payload writable. Restore its recorded mode before retrying the move.
      if Ada.Directories.Exists (Join_Path (Parent, "mode")) then
         declare
            Input : aliased Files.Lease_Streams.Input_Stream;
            Record_Path : constant String := Join_Path (Parent, "mode");
            Mode, Previous, Previous_Group : Natural;
            Expected, Identity : UString;
            Result : Mutation_Result;
         begin
            if not Record_Is_Regular
              (Record_Path, Max_Identity_Length + 32)
            then
               raise Ada.Directories.Use_Error;
            end if;
            if Files.Lease_Streams.Open (Record_Path, Input) /=
                Hostkit.Lease_Files.Opened
              or else Files.Lease_Streams.Size (Input) >
                Max_Identity_Length + 32
            then
               raise Ada.Directories.Use_Error;
            end if;
            Mode := Natural'Input (Input'Access);
            Expected := To_Unbounded_String
              (Files.Bounded_Streams.Input_String
                 (Input'Access, Max_Identity_Length));
            if Mode > 8#7777#
              or else not Files.Lease_Streams.End_Of_Stream (Input)
            then
               raise Ada.Directories.Use_Error;
            end if;
            Files.Lease_Streams.Release (Input);
            if Length (Expected) = 0 then
               raise Ada.Directories.Use_Error;
            end if;
            Result := Change_Metadata
              (Path, To_String (Expected), False, Mode, 0, Previous, Previous_Group, Identity);
            if not Result.Success then
               raise Ada.Directories.Use_Error;
            end if;
         exception
            when others => Files.Lease_Streams.Release (Input); raise;
         end;
      end if;
      if (Expected_Identity /= "" and then not Rename_Item (Path, To_String (Target), Expected_Identity).Success)
        or else (Expected_Identity = "" and then not Support.Move_No_Replace (Path, To_String (Target)))
      then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      begin
         Delete_Tree (Parent);
      exception
         when others => null;
      end;
      Unregister (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore;
end Files.File_System.Recovery;
