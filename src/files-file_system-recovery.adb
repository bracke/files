with Files.File_Identities;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;
with Hostkit.Durability;
with Hostkit.Fs;
with Files.Private_Directories;

package body Files.File_System.Recovery is
   use Ada.Strings.Unbounded;
   use Files.File_System.Support;
   use type Ada.Directories.File_Kind;
   use type Files.Private_Directories.Create_Result;
   use type Hostkit.Durability.Outcome;

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
         Parent : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
      begin
         Delete_Owned_Tree (Parent);
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
   begin
      return Ada.Directories.Simple_Name (Path) = "payload"
        and then Starts_With (Ada.Directories.Simple_Name (Parent), ".files-recovery-")
        and then not Hostkit.Fs.Is_Link (Parent)
        and then Ada.Directories.Exists (Parent)
        and then Ada.Directories.Kind (Parent) = Ada.Directories.Directory
        and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path));
   exception
      when others => return False;
   end Recognizes;

   function Discard (Path : String) return Mutation_Result is
      Parent : constant String := Ada.Directories.Containing_Directory (Path);
   begin
      if not Recognizes (Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      Delete_Owned_Tree (Parent);
      if Ada.Directories.Exists (Parent) or else Hostkit.Fs.Is_Link (Parent) then
         raise Ada.Directories.Use_Error;
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Discard;

   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result is
      Original : constant String := GNAT.OS_Lib.Normalize_Pathname (Path, Resolve_Links => False);
      Parent   : constant String := Ada.Directories.Containing_Directory (Original);
      Stage    : UString;
      File     : Ada.Streams.Stream_IO.File_Type;
   begin
      Backup := Null_Unbounded_String;
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
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Join_Path (To_String (Stage), "original"));
      String'Output (Ada.Streams.Stream_IO.Stream (File), Original);
      Ada.Streams.Stream_IO.Close (File);
      if Hostkit.Durability.Sync_File (Join_Path (To_String (Stage), "original")) /=
        Hostkit.Durability.Synced
      then
         raise Ada.Directories.Use_Error;
      end if;
      if not Hostkit.Fs.Is_Link (Path) and then Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         declare
            Available : Boolean;
            Mode : constant Natural := Permission_Bits_Of (Path, Available);
         begin
            if Available and then (Mode / 8#200#) mod 2 = 0 then
               Ada.Streams.Stream_IO.Create
                 (File, Ada.Streams.Stream_IO.Out_File, Join_Path (To_String (Stage), "mode"));
               Natural'Output (Ada.Streams.Stream_IO.Stream (File), Mode);
               String'Output (Ada.Streams.Stream_IO.Stream (File), Files.File_Identities.Token (Path));
               Ada.Streams.Stream_IO.Close (File);
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
         Safe_Close (File);
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
         end if;
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Preserve;

   function Original_Path (Path : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
      Target : UString;
   begin
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Join_Path (Ada.Directories.Containing_Directory (Path), "original"));
      Target := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      Ada.Streams.Stream_IO.Close (File);
      return To_String (Target);
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Original_Path;

   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result is
      Parent : constant String := Ada.Directories.Containing_Directory (Path);
      Target : UString;
   begin
      Target := To_Unbounded_String
        (if Expected_Original /= "" then Expected_Original else Original_Path (Path));
      if Length (Target) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      if Ada.Directories.Exists (To_String (Target)) or else Hostkit.Fs.Is_Link (To_String (Target)) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;
      --  A failed post-rename permission restoration can leave the private
      --  payload writable. Restore its recorded mode before retrying the move.
      if Ada.Directories.Exists (Join_Path (Parent, "mode")) then
         declare
            File : Ada.Streams.Stream_IO.File_Type;
            Mode, Previous, Previous_Group : Natural;
            Expected, Identity : UString;
            Result : Mutation_Result;
         begin
            Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Join_Path (Parent, "mode"));
            Mode := Natural'Input (Ada.Streams.Stream_IO.Stream (File));
            Expected := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
            Ada.Streams.Stream_IO.Close (File);
            if Length (Expected) = 0 then
               raise Ada.Directories.Use_Error;
            end if;
            Result := Change_Metadata
              (Path, To_String (Expected), False, Mode, 0, Previous, Previous_Group, Identity);
            if not Result.Success then
               raise Ada.Directories.Use_Error;
            end if;
         exception
            when others => Safe_Close (File); raise;
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
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore;
end Files.File_System.Recovery;
