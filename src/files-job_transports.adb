with Ada.Calendar;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with System;

with CryptoLib.OS_Random;
with Files.Durable_Writes;
with Files.File_Identities;
with Files.Private_Directories;
with Hostkit.Fs;

package body Files.Job_Transports is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Interfaces.C.int;
   use type Interfaces.C.long_long;
   use type Files.Private_Directories.Create_Result;

   Marker_Header : constant String := "files-job-transport-4";
   Retiring_Header : constant String := "files-job-transport-retiring-4";
   Truncated_Lease_Header : constant String := "files-job-transport-3";
   Truncated_Retiring_Header : constant String := "files-job-transport-retiring-3";
   Unbound_Marker_Header : constant String := "files-job-transport-2";
   Pre_Lease_Marker_Header : constant String := "files-job-transport-1";
   Marker_Name   : constant String := ".files-job-transport";
   Lease_Name    : constant String := ".files-job-owner";
   Transport_Prefix : constant String := "files-job-";
   Witness_Prefix : constant String := ".files-job-creation-";
   Hex_Digits : constant String := "0123456789abcdef";

   function Create_Lease_Native (Name : System.Address) return Interfaces.C.long_long
     with Import, Convention => C, External_Name => "files_transport_lease_create";
   function Claim_Lease_Native
     (Name, Outcome : System.Address) return Interfaces.C.long_long
     with Import, Convention => C, External_Name => "files_transport_lease_claim";
   function Join_Lease_Native (Name : System.Address) return Interfaces.C.long_long
     with Import, Convention => C, External_Name => "files_transport_lease_join";
   procedure Release_Lease_Native (Handle : Interfaces.C.long_long)
     with Import, Convention => C, External_Name => "files_transport_lease_release";
   type Native_Identity is array (1 .. 5) of Interfaces.C.unsigned_long_long
     with Convention => C;
   function Lease_Identity_Native
     (Handle : Interfaces.C.long_long; Value : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_identity";
   function Set_Lease_Nonce_Native
     (Handle : Interfaces.C.long_long; Value : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_set_nonce";
   function Prepare_Witness_Native (Handle : Interfaces.C.long_long) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_prepare_witness";
   function Publish_Witness_Native (Handle : Interfaces.C.long_long) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_publish_witness";
   function Witness_State_Native (Handle : Interfaces.C.long_long) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_witness_state";
   function Lease_Path_Matches_Native
     (Handle : Interfaces.C.long_long; Name : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_transport_lease_path_matches";

   function Lease_Token (Handle : Interfaces.C.long_long) return String is
      Value : aliased Native_Identity;
   begin
      if Handle = 0 or else Lease_Identity_Native (Handle, Value'Address) /= 1 then
         return "";
      end if;
      declare
         Result : Unbounded_String;
      begin
         for Part of Value loop
            Append (Result, Interfaces.C.unsigned_long_long'Image (Part));
         end loop;
         return To_String (Result);
      end;
   end Lease_Token;

   procedure Release (Owner : in out Lease) is
   begin
      if Owner.Handle /= 0 then
         Release_Lease_Native (Owner.Handle);
         Owner.Handle := 0;
      end if;
      Owner.Exclusive := False;
      Owner.Directory := Null_Unbounded_String;
      Owner.Identity := Null_Unbounded_String;
   end Release;

   overriding procedure Finalize (Owner : in out Lease) is
   begin
      Release (Owner);
   end Finalize;

   function Claim_Lease
     (Name  : in out Interfaces.C.char_array;
      Owner : in out Lease) return Claim_Outcome
   is
      Native_Outcome : aliased Interfaces.C.int := 0;
   begin
      Owner.Handle := Claim_Lease_Native (Name'Address, Native_Outcome'Address);
      if Owner.Handle /= 0 then
         Owner.Exclusive := True;
         return Claim_Acquired;
      end if;
      return
        (case Native_Outcome is
           when 2      => Claim_Busy,
           when 3      => Claim_Refused,
           when others => Claim_Error);
   end Claim_Lease;

   function Random_Name return String is
      Bytes   : Ada.Streams.Stream_Element_Array (1 .. 16);
      Success : Boolean;
      Result  : String (1 .. 2 * Bytes'Length);
      Cursor  : Positive := Result'First;
   begin
      CryptoLib.OS_Random.Fill_OS (Bytes, Success);
      if not Success then
         raise Ada.Directories.Use_Error;
      end if;
      for Byte of Bytes loop
         Result (Cursor) := Hex_Digits (Natural (Byte) / 16 + 1);
         Result (Cursor + 1) := Hex_Digits (Natural (Byte) mod 16 + 1);
         Cursor := Cursor + 2;
      end loop;
      return Result;
   end Random_Name;

   function Is_Transport_Path (Directory : String) return Boolean is
      Name : constant String := Ada.Directories.Simple_Name (Directory);
      Suffix_First : constant Positive := Name'First + Transport_Prefix'Length;
   begin
      return Name'Length = Transport_Prefix'Length + 32
        and then Name (Name'First .. Name'First + Transport_Prefix'Length - 1) = Transport_Prefix
        and then (for all Position in Suffix_First .. Name'Last =>
          Name (Position) in '0' .. '9' | 'a' .. 'f')
        and then Ada.Directories.Full_Name (Ada.Directories.Containing_Directory (Directory)) =
          Ada.Directories.Full_Name (Hostkit.Fs.Temp_Directory);
   exception
      when others => return False;
   end Is_Transport_Path;

   function Witness_Path (Directory : String) return String is
      Name : constant String := Ada.Directories.Simple_Name (Directory);
   begin
      return Hostkit.Fs.Join
        (Hostkit.Fs.Temp_Directory,
         Witness_Prefix & Name (Name'First + Transport_Prefix'Length .. Name'Last));
   end Witness_Path;

   procedure Forget_Witness (Directory : String; Owner : in out Lease) is
      Path : constant String := Witness_Path (Directory);
      Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      Same : constant Boolean := Owner.Handle /= 0
        and then Is_Transport_Path (Directory)
        and then Lease_Path_Matches_Native (Owner.Handle, Name'Address) = 1;
   begin
      Release (Owner);
      if Same then
         begin
            Ada.Directories.Delete_File (Path);
         exception
            when others => null;
         end;
      end if;
   exception
      when others => Release (Owner);
   end Forget_Witness;

   procedure Mark
     (Directory, Owner_Token : String;
      Identity : out Files.Types.UString;
      Header : String := Marker_Header) is
      File   : Ada.Streams.Stream_IO.File_Type;
      Marker : constant String := Hostkit.Fs.Join (Directory, Marker_Name);
      Temp   : constant String := Marker & ".tmp";
   begin
      Identity := To_Unbounded_String (Files.File_Identities.Token (Directory));
      if not Is_Transport_Path (Directory)
        or else Length (Identity) = 0
        or else Owner_Token = ""
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
      then
         raise Ada.Directories.Use_Error;
      end if;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Temp);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Header);
      String'Output (Ada.Streams.Stream_IO.Stream (File), Directory);
      String'Output (Ada.Streams.Stream_IO.Stream (File), To_String (Identity));
      String'Output (Ada.Streams.Stream_IO.Stream (File), Owner_Token);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Publish (Temp, Marker) then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         begin
            if Ada.Directories.Exists (Temp) then
               Ada.Directories.Delete_File (Temp);
            end if;
         exception
            when others => null;
         end;
         Identity := Null_Unbounded_String;
         raise;
   end Mark;

   procedure Create
     (Directory : out Files.Types.UString;
      Identity  : out Files.Types.UString;
      Owner     : out Lease)
   is
      procedure Remove_Failed_Candidate (Candidate : String) is
         procedure Remove_File (Name : String) is
         begin
            if Ada.Directories.Exists (Name) or else Hostkit.Fs.Is_Link (Name) then
               Ada.Directories.Delete_File (Name);
            end if;
         exception
            when others => null;
         end Remove_File;
      begin
         --  Only fixed protocol files can exist before Create returns. Remove
         --  each independently so one transient failure does not prevent the
         --  remaining rollback work.
         Remove_File (Hostkit.Fs.Join (Candidate, Marker_Name & ".tmp"));
         Remove_File (Hostkit.Fs.Join (Candidate, Marker_Name));
         Remove_File (Hostkit.Fs.Join (Candidate, Lease_Name));
         begin
            Ada.Directories.Delete_Directory (Candidate);
         exception
            when others => null;
         end;
      end Remove_Failed_Candidate;
   begin
      Release (Owner);
      Directory := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      for Attempt in 1 .. 100 loop
         declare
            Candidate : constant String :=
              Hostkit.Fs.Join (Hostkit.Fs.Temp_Directory, Transport_Prefix & Random_Name);
            Witness : Lease;
            Witness_Name : aliased Interfaces.C.char_array :=
              Interfaces.C.To_C (Witness_Path (Candidate));
         begin
            --  The witness is created before the directory. A crash in the
            --  pre-marker window leaves a lockable proof of this attempt.
            Witness.Handle := Create_Lease_Native (Witness_Name'Address);
            if Witness.Handle = 0 then
               goto Continue;
            end if;
            if Prepare_Witness_Native (Witness.Handle) /= 1 then
               Forget_Witness (Candidate, Witness);
               raise Ada.Directories.Use_Error;
            end if;
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               Forget_Witness (Candidate, Witness);
               goto Continue;
            end if;
            begin
               --  Perform the last potentially allocating output assignment
               --  before publishing either the lease or ownership marker.
               Directory := To_Unbounded_String (Candidate);
               declare
                  Lease_Path : aliased Interfaces.C.char_array :=
                    Interfaces.C.To_C (Hostkit.Fs.Join (Candidate, Lease_Name));
               begin
                  Owner.Handle := Create_Lease_Native (Lease_Path'Address);
                  if Owner.Handle = 0 then
                     raise Ada.Directories.Use_Error;
                  end if;
               end;
               declare
                  Nonce : aliased Ada.Streams.Stream_Element_Array (1 .. 16);
                  Success : Boolean;
               begin
                  CryptoLib.OS_Random.Fill_OS (Nonce, Success);
                  if not Success or else
                    Set_Lease_Nonce_Native (Owner.Handle, Nonce'Address) /= 1
                  then
                     raise Ada.Directories.Use_Error;
                  end if;
               end;
               Mark (Candidate, Lease_Token (Owner.Handle), Identity);
               Owner.Directory := Directory;
               Owner.Identity := Identity;
               if Publish_Witness_Native (Witness.Handle) /= 1 then
                  raise Ada.Directories.Use_Error;
               end if;
               Forget_Witness (Candidate, Witness);
               return;
            exception
               when others =>
                  Release (Owner);
                  Remove_Failed_Candidate (Candidate);
                  if not Ada.Directories.Exists (Candidate) then
                     Forget_Witness (Candidate, Witness);
                  end if;
                  Directory := Null_Unbounded_String;
                  Identity := Null_Unbounded_String;
                  raise;
            end;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   end Create;

   procedure Read_Marker
     (Directory : String;
      Identity  : out Files.Types.UString;
      Owner_Token : out Files.Types.UString;
      Current   : out Boolean;
      Retiring  : out Boolean;
      Valid     : out Boolean;
      Read_Error : out Boolean)
   is
      File     : Ada.Streams.Stream_IO.File_Type;
      Marker   : constant String := Hostkit.Fs.Join (Directory, Marker_Name);
      Header   : Files.Types.UString;
      Recorded_Directory : Files.Types.UString;
   begin
      Identity := Null_Unbounded_String;
      Owner_Token := Null_Unbounded_String;
      Current := False;
      Retiring := False;
      Valid := False;
      Read_Error := False;
      if Directory = ""
        or else not Is_Transport_Path (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else Hostkit.Fs.Is_Link (Marker)
        or else not Ada.Directories.Exists (Marker)
        or else Ada.Directories.Kind (Marker) /= Ada.Directories.Ordinary_File
      then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Marker);
      Header := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      if To_String (Header) not in Marker_Header | Retiring_Header
        | Truncated_Lease_Header | Truncated_Retiring_Header
        | Unbound_Marker_Header | Pre_Lease_Marker_Header
      then
         Ada.Streams.Stream_IO.Close (File);
         return;
      end if;
      Recorded_Directory := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      Identity := To_Unbounded_String (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      if To_String (Header) in Marker_Header | Retiring_Header
        | Truncated_Lease_Header | Truncated_Retiring_Header
      then
         Owner_Token := To_Unbounded_String
           (String'Input (Ada.Streams.Stream_IO.Stream (File)));
      end if;
      Ada.Streams.Stream_IO.Close (File);
      if To_String (Recorded_Directory) /= Directory
        or else Length (Identity) = 0
        or else (To_String (Header) in Marker_Header | Retiring_Header
          | Truncated_Lease_Header | Truncated_Retiring_Header
          and then Length (Owner_Token) = 0)
        or else Files.File_Identities.Token (Directory) /= To_String (Identity)
      then
         Identity := Null_Unbounded_String;
         Owner_Token := Null_Unbounded_String;
         return;
      end if;
      Current := To_String (Header) in Marker_Header | Retiring_Header;
      Retiring := To_String (Header) = Retiring_Header;
      Valid := True;
   exception
      when Ada.IO_Exceptions.End_Error | Ada.IO_Exceptions.Data_Error | Constraint_Error =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         Identity := Null_Unbounded_String;
         Owner_Token := Null_Unbounded_String;
         Current := False;
         Retiring := False;
         Valid := False;
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         Identity := Null_Unbounded_String;
         Owner_Token := Null_Unbounded_String;
         Current := False;
         Retiring := False;
         Valid := False;
         Read_Error := True;
   end Read_Marker;

   procedure Inspect_Marker
     (Directory  : String;
      Identity   : out Files.Types.UString;
      Read_Error : out Boolean)
   is
      Current : Boolean;
      Retiring : Boolean;
      Valid   : Boolean;
      Owner_Token : Files.Types.UString;
   begin
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      if not Valid then
         Identity := Null_Unbounded_String;
      end if;
   end Inspect_Marker;

   function Recorded_Identity (Directory : String) return String is
      Identity : Files.Types.UString;
      Current  : Boolean;
      Retiring : Boolean;
      Valid    : Boolean;
      Read_Error : Boolean;
      Owner_Token : Files.Types.UString;
   begin
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      return (if Valid then To_String (Identity) else "");
   end Recorded_Identity;

   function Matches (Directory, Expected_Identity : String) return Boolean is
     (Expected_Identity /= ""
      and then Recorded_Identity (Directory) = Expected_Identity);

   function Holds (Owner : Lease; Directory : String) return Boolean is
      Identity : Files.Types.UString;
      Owner_Token : Files.Types.UString;
      Current : Boolean;
      Retiring : Boolean;
      Valid : Boolean;
      Read_Error : Boolean;
      Lease_Path : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C (Hostkit.Fs.Join (Directory, Lease_Name));
   begin
      if Owner.Handle = 0
        or else To_String (Owner.Directory) /= Directory
        or else Length (Owner.Identity) = 0
        or else Lease_Path_Matches_Native (Owner.Handle, Lease_Path'Address) /= 1
      then
         return False;
      end if;
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      return Valid and then Current
        and then Identity = Owner.Identity
        and then To_String (Owner_Token) = Lease_Token (Owner.Handle);
   exception
      when others => return False;
   end Holds;

   function Retire (Owner : Lease; Directory : String) return Boolean is
      Identity : Files.Types.UString;
   begin
      if not Owner.Exclusive or else not Holds (Owner, Directory) then
         return False;
      end if;
      Mark (Directory, Lease_Token (Owner.Handle), Identity, Retiring_Header);
      return Identity = Owner.Identity;
   exception
      when others => return False;
   end Retire;

   function Join_Helper (Directory : String; Owner : in out Lease) return Boolean is
      Identity : Files.Types.UString;
      Owner_Token : Files.Types.UString;
      Current : Boolean;
      Retiring : Boolean;
      Valid : Boolean;
      Read_Error : Boolean;
      Lease_Path : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C (Hostkit.Fs.Join (Directory, Lease_Name));
   begin
      if Owner.Handle /= 0 then
         return False;
      end if;
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      if not Valid or else not Current or else Retiring then
         return False;
      end if;
      Owner.Handle := Join_Lease_Native (Lease_Path'Address);
      if Owner.Handle = 0 then
         return False;
      end if;
      Owner.Directory := To_Unbounded_String (Directory);
      Owner.Identity := Identity;
      if not Holds (Owner, Directory) then
         Release (Owner);
         return False;
      end if;
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      if not Valid or else Retiring then
         Release (Owner);
         return False;
      end if;
      return True;
   exception
      when others =>
         Release (Owner);
         return False;
   end Join_Helper;

   function Claim_Abandoned
     (Directory, Expected_Identity : String;
      Owner : in out Lease) return Claim_Outcome
   is
      Identity : Files.Types.UString;
      Current  : Boolean;
      Retiring : Boolean;
      Valid    : Boolean;
      Read_Error : Boolean;
      Owner_Token : Files.Types.UString;
   begin
      Read_Marker (Directory, Identity, Owner_Token, Current, Retiring, Valid, Read_Error);
      if Read_Error then
         return Claim_Error;
      end if;
      if Owner.Handle /= 0
        or else not Valid
        or else To_String (Identity) /= Expected_Identity
      then
         return Claim_Refused;
      end if;
      if not Current then
         --  Earlier marker formats do not bind the lease inode. A live owner
         --  may still hold a lock on an unlinked predecessor.
         return Claim_Unrecoverable;
      end if;
      declare
         Lease_Path : aliased Interfaces.C.char_array :=
           Interfaces.C.To_C (Hostkit.Fs.Join (Directory, Lease_Name));
      begin
         if Current
           and then not Ada.Directories.Exists
             (Hostkit.Fs.Join (Directory, Lease_Name))
           and then not Hostkit.Fs.Is_Link
             (Hostkit.Fs.Join (Directory, Lease_Name))
         then
            --  The owner might still hold a lock on an unlinked lease inode.
            --  Do not create a second lease and clean a potentially live job.
            --  A partial owned-tree deletion retains its lease until last;
            --  unexpected external removal is a terminal unsafe condition.
            return Claim_Unrecoverable;
         end if;
         declare
            Outcome : constant Claim_Outcome := Claim_Lease (Lease_Path, Owner);
         begin
            if Outcome /= Claim_Acquired then
               --  A previously present lease may have been removed or
               --  replaced between inspection and open. Neither case proves
               --  that the original owner has stopped.
               return (if Outcome = Claim_Refused then Claim_Unrecoverable else Outcome);
            end if;
         end;
         if Lease_Token (Owner.Handle) /= To_String (Owner_Token) then
            Release (Owner);
            return Claim_Unrecoverable;
         end if;
         Owner.Directory := To_Unbounded_String (Directory);
         Owner.Identity := Identity;
         return Claim_Acquired;
      end;
   exception
      when others =>
         Release (Owner);
         return Claim_Error;
   end Claim_Abandoned;

   function Claim_Incomplete
     (Directory   : String;
      Identity    : out Files.Types.UString;
      Owner       : in out Lease;
      Minimum_Age : Duration := 1.0) return Claim_Outcome
   is
      Search       : Ada.Directories.Search_Type;
      Item         : Ada.Directories.Directory_Entry_Type;
      Lease_Path   : constant String := Hostkit.Fs.Join (Directory, Lease_Name);
      Marker_Path  : constant String := Hostkit.Fs.Join (Directory, Marker_Name);
      Marker_Temp  : constant String := Marker_Path & ".tmp";
      Witness_Name : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C (Witness_Path (Directory));
      Search_Open  : Boolean := False;
      Protocol_Error : Boolean := False;

      function Protocol_Only return Boolean is
         Filter : constant Ada.Directories.Filter_Type := [others => True];
      begin
         Ada.Directories.Start_Search (Search, Directory, "*", Filter);
         Search_Open := True;
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
            begin
               if Name not in "." | ".." | Lease_Name | Marker_Name & ".tmp" then
                  Ada.Directories.End_Search (Search);
                  Search_Open := False;
                  return False;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         Search_Open := False;
         return True;
      exception
         when others =>
            Protocol_Error := True;
            if Search_Open then
               begin
                  Ada.Directories.End_Search (Search);
               exception
                  when others => null;
               end;
               Search_Open := False;
            end if;
            return False;
      end Protocol_Only;
   begin
      Identity := Null_Unbounded_String;
      if Owner.Handle /= 0
        or else not Is_Transport_Path (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else (Ada.Directories.Exists (Marker_Temp)
          and then (Hostkit.Fs.Is_Link (Marker_Temp)
            or else Ada.Directories.Kind (Marker_Temp) /= Ada.Directories.Ordinary_File))
      then
         return Claim_Refused;
      end if;
      if Ada.Directories.Exists (Marker_Path) or else Hostkit.Fs.Is_Link (Marker_Path) then
         return Claim_Deferred;
      end if;

      if not Protocol_Only then
         return (if Protocol_Error then Claim_Error else Claim_Refused);
      end if;
      if not Ada.Directories.Exists (Interfaces.C.To_Ada (Witness_Name)) then
         return Claim_Unrecoverable;
      end if;
      declare
         Outcome : constant Claim_Outcome := Claim_Lease (Witness_Name, Owner);
      begin
         if Outcome = Claim_Busy then
            return Claim_Deferred;
         elsif Outcome /= Claim_Acquired then
            return Outcome;
         end if;
      end;
      if Ada.Directories.Exists (Marker_Path) or else Hostkit.Fs.Is_Link (Marker_Path) then
         Release (Owner);
         return Claim_Deferred;
      end if;
      if Lease_Path_Matches_Native (Owner.Handle, Witness_Name'Address) /= 1
        or else not Protocol_Only
      then
         Release (Owner);
         return (if Protocol_Error then Claim_Error else Claim_Refused);
      end if;
      if Witness_State_Native (Owner.Handle) /= 1 then
         Release (Owner);
         return Claim_Unrecoverable;
      end if;
      Identity := To_Unbounded_String (Files.File_Identities.Token (Directory));
      declare
         Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Modified : constant Ada.Calendar.Time :=
           Ada.Directories.Modification_Time (Directory);
      begin
         if Modified <= Now
           and then Now - Modified < Duration'Max (0.0, Minimum_Age)
         then
            Release (Owner);
            Identity := Null_Unbounded_String;
            return Claim_Deferred;
         end if;
      end;
      Owner.Directory := To_Unbounded_String (Directory);
      Owner.Identity := Identity;
      return Claim_Acquired;
   exception
      when others =>
         if Search_Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
         Release (Owner);
         Identity := Null_Unbounded_String;
         return Claim_Error;
   end Claim_Incomplete;

   function Remove_Empty_Incomplete (Directory : String; Owner : Lease) return Boolean is
      Temp : constant String := Hostkit.Fs.Join (Directory, Marker_Name & ".tmp");
      Lease_Path : constant String := Hostkit.Fs.Join (Directory, Lease_Name);
      Witness_Name : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C (Witness_Path (Directory));
      Lease_Name_C : aliased Interfaces.C.char_array := Interfaces.C.To_C (Lease_Path);
      Lease_Claim : Lease;
   begin
      if Owner.Handle = 0 or else not Owner.Exclusive
        or else not Is_Transport_Path (Directory)
        or else Lease_Path_Matches_Native (Owner.Handle, Witness_Name'Address) /= 1
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else Ada.Directories.Exists (Hostkit.Fs.Join (Directory, Marker_Name))
        or else Hostkit.Fs.Is_Link (Hostkit.Fs.Join (Directory, Marker_Name))
      then
         return False;
      end if;
      if Ada.Directories.Exists (Temp) then
         if Hostkit.Fs.Is_Link (Temp)
           or else Ada.Directories.Kind (Temp) /= Ada.Directories.Ordinary_File
         then
            return False;
         end if;
         Ada.Directories.Delete_File (Temp);
      end if;
      if Ada.Directories.Exists (Lease_Path) or else Hostkit.Fs.Is_Link (Lease_Path) then
         if Claim_Lease (Lease_Name_C, Lease_Claim) /= Claim_Acquired
           or else Lease_Path_Matches_Native (Lease_Claim.Handle, Lease_Name_C'Address) /= 1
         then
            return False;
         end if;
         Release (Lease_Claim);
         Ada.Directories.Delete_File (Lease_Path);
      end if;
      Ada.Directories.Delete_Directory (Directory);
      return True;
   exception
      when others => return False;
   end Remove_Empty_Incomplete;

   procedure Scavenge_Witnesses is
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Open : Boolean := False;
      Filter : constant Ada.Directories.Filter_Type := [others => True];
   begin
      Ada.Directories.Start_Search
        (Search, Hostkit.Fs.Temp_Directory, Witness_Prefix & "*", Filter);
      Open := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length = Witness_Prefix'Length + 32
              and then Name (Name'First .. Name'First + Witness_Prefix'Length - 1) = Witness_Prefix
              and then (for all Position in Name'First + Witness_Prefix'Length .. Name'Last =>
                Name (Position) in '0' .. '9' | 'a' .. 'f')
            then
               declare
                  Directory : constant String := Hostkit.Fs.Join
                    (Hostkit.Fs.Temp_Directory,
                     Transport_Prefix & Name (Name'First + Witness_Prefix'Length .. Name'Last));
                  Witness_Name : aliased Interfaces.C.char_array :=
                    Interfaces.C.To_C (Ada.Directories.Full_Name (Item));
                  Owner : Lease;
               begin
                  if Claim_Lease (Witness_Name, Owner) = Claim_Acquired then
                     if (not Ada.Directories.Exists (Directory) and then not Hostkit.Fs.Is_Link (Directory))
                       or else Recorded_Identity (Directory) /= ""
                     then
                        Forget_Witness (Directory, Owner);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      Open := False;
   exception
      when others =>
         if Open then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others => null;
            end;
         end if;
   end Scavenge_Witnesses;
end Files.Job_Transports;
