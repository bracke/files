with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Bounded_Streams;
with Files.File_System;
with Files.Fs;
with Files.Durable_Writes;
with Files.Private_Directories;
with Files.Process_Jobs;
with Hostkit.Durability;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.File_Identities;
with Files.Lease_Streams;

package body Files.Job_Context is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;
   use type Files.Private_Directories.Create_Result;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Hostkit.Durability.Outcome;
   use type Hostkit.Lease_Files.Open_Outcome;

   Stage_Record_Header : constant String := "files-stage-3";
   Created_Record_Header : constant String := "files-created-3";
   Max_Record_Header_Length : constant := 128;
   Max_Record_Path_Length : constant := 32 * 1024;
   Max_Record_Token_Length : constant := 2 * 1024;
   Max_Stage_Metadata_Bytes : constant := 64 * 1024;
   Max_Journal_Bytes : constant := 64 * 1024 * 1024;
   Max_Journal_Records : constant := 100_000;
   Encoded_String_Overhead : constant := 16;
   Max_Append_Bytes : constant :=
     2 * Max_Record_Path_Length + 2 * Max_Record_Token_Length
       + Max_Record_Header_Length + 5 * Encoded_String_Overhead;
   Foreground_Job : Files.Process_Jobs.Session;
   Foreground_Paths : Files.Types.String_Vectors.Vector;
   Foreground_Records : Files.Types.String_Vectors.Vector;

   type Descriptor_Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   end record;

   overriding procedure Read
     (Stream : in out Descriptor_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Descriptor_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

   overriding procedure Read
     (Stream : in out Descriptor_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   overriding procedure Write
     (Stream : in out Descriptor_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      Next    : Ada.Streams.Stream_Element_Offset := Item'First;
      Written : Integer;
   begin
      while Next <= Item'Last loop
         Written := GNAT.OS_Lib.Write
           (Stream.Descriptor, Item (Next)'Address,
            Integer (Item'Last - Next + 1));
         if Written <= 0 then
            raise Ada.Directories.Use_Error;
         end if;
         Next := Next + Ada.Streams.Stream_Element_Offset (Written);
      end loop;
   end Write;

   subtype Append_Buffer is Ada.Streams.Stream_Element_Array
     (1 .. Ada.Streams.Stream_Element_Offset (Max_Append_Bytes));

   type Memory_Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Data : Append_Buffer := [others => 0];
      Last : Ada.Streams.Stream_Element_Offset := 0;
   end record;

   overriding procedure Read
     (Stream : in out Memory_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Memory_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

   overriding procedure Read
     (Stream : in out Memory_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   overriding procedure Write
     (Stream : in out Memory_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array) is
   begin
      if Ada.Streams.Stream_Element_Offset (Item'Length) >
        Stream.Data'Last - Stream.Last
      then
         raise Ada.Directories.Use_Error;
      end if;
      for Value of Item loop
         Stream.Last := Stream.Last + 1;
         Stream.Data (Stream.Last) := Value;
      end loop;
   end Write;

   function Nul_Free (Value : String) return Boolean is
   begin
      for Item of Value loop
         if Item = ASCII.NUL then
            return False;
         end if;
      end loop;
      return True;
   end Nul_Free;

   function Valid_Absolute_Path (Path : String) return Boolean is
   begin
      if Path = "" or else Path'Length > Max_Record_Path_Length then
         return False;
      end if;
      return Nul_Free (Path) and then GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others =>
         return False;
   end Valid_Absolute_Path;

   procedure Sync_Journal (Path : String);

   procedure Publish_Record
     (Temporary, Target : String;
      Write_Record : not null access procedure
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
   is
      Output : aliased Descriptor_Output_Stream :=
        (Ada.Streams.Root_Stream_Type with
         Descriptor => GNAT.OS_Lib.Invalid_FD);
      Temporary_Identity : Files.Types.UString;

      procedure Remove_Owned_Temporary is
      begin
         if Length (Temporary_Identity) > 0
           and then Files.File_Identities.Token (Temporary) =
             To_String (Temporary_Identity)
         then
            Ada.Directories.Delete_File (Temporary);
         end if;
      exception
         when others =>
            null;
      end Remove_Owned_Temporary;
   begin
      if Hostkit.Fs.Is_Link (Temporary)
        or else Ada.Directories.Exists (Temporary)
        or else Hostkit.Fs.Is_Link (Target)
        or else (Ada.Directories.Exists (Target)
          and then Ada.Directories.Kind (Target) /= Ada.Directories.Ordinary_File)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Output.Descriptor :=
        GNAT.OS_Lib.Create_New_File (Temporary, GNAT.OS_Lib.Binary);
      if Output.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.Directories.Use_Error;
      end if;
      Temporary_Identity := To_Unbounded_String
        (Files.File_Identities.Token (Temporary));
      if Length (Temporary_Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Output.Descriptor);
      Write_Record (Output'Access);
      declare
         Closed : Boolean;
      begin
         GNAT.OS_Lib.Close (Output.Descriptor, Closed);
         Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            raise Ada.Directories.Use_Error;
         end if;
      end;
      if Files.File_Identities.Token (Temporary) /=
        To_String (Temporary_Identity)
      then
         raise Ada.Directories.Use_Error;
      end if;
      if not Files.Durable_Writes.Published
        (Files.Durable_Writes.Publish (Temporary, Target))
      then
         raise Ada.Directories.Use_Error;
      end if;
      Temporary_Identity := Null_Unbounded_String;
   exception
      when others =>
         if Output.Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Output.Descriptor);
            Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         Remove_Owned_Temporary;
         raise;
   end Publish_Record;

   procedure Append_Journal_Record
     (Name, Header : String;
      Write_Record : not null access procedure
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
   is
      Journal : constant String := Hostkit.Fs.Join (To_String (Current), Name);
      Existing : constant Boolean :=
        Ada.Directories.Exists (Journal) or else Hostkit.Fs.Is_Link (Journal);
      Handle : Hostkit.Lease_Files.Lease;
      Opened : Hostkit.Lease_Files.Open_Outcome;
      Buffer : aliased Memory_Output_Stream;
      Size   : Long_Long_Integer;
      Offset : Ada.Streams.Stream_Element_Offset;
   begin
      if Existing then
         Opened := Hostkit.Lease_Files.Open
           (Journal, Hostkit.Lease_Files.Exclusive, Writable => True,
            Item => Handle);
      else
         Opened := Hostkit.Lease_Files.Create (Journal, Handle);
      end if;
      if Opened /= Hostkit.Lease_Files.Opened then
         raise Ada.Directories.Use_Error;
      end if;
      Size := Hostkit.Lease_Files.Size (Handle);
      if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes) then
         raise Ada.Directories.Use_Error;
      end if;
      if not Existing then
         String'Output (Buffer'Access, Header);
      end if;
      Write_Record (Buffer'Access);
      if Long_Long_Integer (Buffer.Last) >
        Long_Long_Integer (Max_Journal_Bytes) - Size
      then
         raise Ada.Directories.Use_Error;
      end if;
      Offset := Ada.Streams.Stream_Element_Offset (Size);
      if Buffer.Last = 0
        or else not Hostkit.Lease_Files.Write_At
          (Handle, Buffer.Data (Buffer.Data'First .. Buffer.Last), Offset)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Hostkit.Lease_Files.Release (Handle);
      Sync_Journal (Journal);
   exception
      when others =>
         Hostkit.Lease_Files.Release (Handle);
         raise;
   end Append_Journal_Record;

   procedure Sync_Journal (Path : String) is
   begin
      if Hostkit.Durability.Sync_File (Path) = Hostkit.Durability.Synced then
         declare
            Outcome : constant Hostkit.Durability.Outcome :=
              Hostkit.Durability.Sync_Directory (Ada.Directories.Containing_Directory (Path));
            pragma Unreferenced (Outcome);
         begin
            null;
         end;
      end if;
   exception
      when others => null;
   end Sync_Journal;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String);

   procedure Remove_Record (Record_Directory : String) is
   begin
      if Record_Directory /= ""
        and then not Hostkit.Fs.Is_Link (Record_Directory)
        and then Ada.Directories.Exists (Record_Directory)
      then
         Files.Fs.Delete_Tree (Record_Directory);
      end if;
   exception
      when others => null;
   end Remove_Record;

   procedure Initialize (Directory : String) is
   begin
      if Directory /= "" and then not Valid_Absolute_Path (Directory) then
         raise Ada.Directories.Use_Error;
      end if;
      Current := To_Unbounded_String (Directory);
   end Initialize;

   procedure Shutdown is
   begin
      Files.Process_Jobs.Release_For_Shutdown (Foreground_Job);
      Foreground_Paths.Clear;
      Foreground_Records.Clear;
   end Shutdown;

   function Directory return String is (To_String (Current));

   function Cancelled return Boolean is
     (Files.Process_Jobs.Cancellation_Requested (To_String (Current)));

   procedure Create_Private_Directory (Path : String) is
   begin
      Files.Private_Directories.Create (Path);
   end Create_Private_Directory;

   function Stage_Owner_Directory return String is
   begin
      if Length (Current) > 0 then
         return To_String (Current);
      end if;
      if not Files.Process_Jobs.Active (Foreground_Job) then
         Files.Process_Jobs.Reserve (Foreground_Job);
      end if;
      return Files.Process_Jobs.Path (Foreground_Job, "");
   end Stage_Owner_Directory;

   procedure Write_Stage_Record
     (Record_Directory, Path, Identity : String)
   is
      Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
      Temp : constant String := Hostkit.Fs.Join (Record_Directory, "data.tmp");
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Stage_Record_Header);
         String'Output (Stream, Path);
         String'Output (Stream, Identity);
      end Write;
   begin
      if not Valid_Absolute_Path (Record_Directory)
        or else not Valid_Absolute_Path (Path)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Publish_Record (Temp, Data, Write'Access);
   end Write_Stage_Record;

   function Begin_Stage_Record (Path : String) return String is
      Owner_Directory : constant String := Stage_Owner_Directory;
      Stages : constant String := Hostkit.Fs.Join (Owner_Directory, "stages");
   begin
      if Files.Private_Directories.Try_Create (Stages) =
        Files.Private_Directories.Collision
        and then (Hostkit.Fs.Is_Link (Stages) or else not Ada.Directories.Exists (Stages)
          or else Ada.Directories.Kind (Stages) /= Ada.Directories.Directory)
      then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Record_Directory : constant String :=
              Hostkit.Fs.Join (Stages, "stage-" & Image (2 .. Image'Last));
         begin
            if Files.Private_Directories.Try_Create (Record_Directory) =
              Files.Private_Directories.Collision
            then
               goto Continue;
            end if;
            begin
               --  Publish the intended pathname before creating it. A crash
               --  can therefore leave an unfinished record, never an
               --  undiscoverable staging directory.
               Write_Stage_Record (Record_Directory, Path, "");
               return Record_Directory;
            exception
               when others =>
                  Remove_Record (Record_Directory);
                  raise;
            end;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   end Begin_Stage_Record;

   function Create_Stage (Parent : String) return String is
   begin
      if not Valid_Absolute_Path (Parent) then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Candidate : constant String := Hostkit.Fs.Join (Parent, ".files-work-" & Image (2 .. Image'Last));
            Identity : Files.Types.UString;
            Record_Directory : Files.Types.UString;
         begin
            Record_Directory := To_Unbounded_String (Begin_Stage_Record (Candidate));
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               Remove_Record (To_String (Record_Directory));
               goto Continue;
            end if;
            begin
               Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               if Length (Identity) = 0 then
                  raise Ada.Directories.Use_Error;
               end if;
            exception
               when others =>
                  begin
                     Ada.Directories.Delete_Directory (Candidate);
                     Remove_Record (To_String (Record_Directory));
                  exception
                     when others => null;
                  end;
                  raise;
            end;
            begin
               Register_Stage_Internal
                 (Candidate, To_String (Identity), To_String (Record_Directory));
            exception
               when others =>
                  declare
                     Removed : constant Files.File_System.Mutation_Result :=
                       Files.File_System.Delete_Staging_Entry
                         (Candidate, To_String (Identity));
                     pragma Unreferenced (Removed);
                  begin
                     null;
                  end;
                  if not (Ada.Directories.Exists (Candidate) or else Hostkit.Fs.Is_Link (Candidate)) then
                     Remove_Record (To_String (Record_Directory));
                  end if;
                  raise;
            end;
            if Length (Current) = 0 then
               Foreground_Paths.Append (To_Unbounded_String (Candidate));
               Foreground_Records.Append (Record_Directory);
            end if;
            return Candidate;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   exception
      when others =>
         if Length (Current) = 0 and then Foreground_Paths.Is_Empty
           and then Files.Process_Jobs.Active (Foreground_Job)
         then
            Files.Process_Jobs.Reset (Foreground_Job);
         end if;
         raise;
   end Create_Stage;

   procedure Append_Record (Name, Header, Destination, Source, Identity : String);

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String) return Boolean
   is
      Is_Link : Boolean;
   begin
      if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
         return False;
      end if;
      Is_Link := Hostkit.Fs.Is_Link (Path);
      return
        (if Is_Link then Tree_Revision = ""
         else Tree_Revision /= ""
           and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when others =>
         return False;
   end Creation_Snapshot_Matches;

   procedure Record_Created (Destination : String; Source : String := "") is
   begin
      Record_Created (Destination, Source, Files.File_Identities.Token (Destination));
   end Record_Created;

   procedure Record_Created (Destination, Source, Identity : String) is
   begin
      Record_Created (Destination, Source, Identity, Files.File_System.Tree_Revision (Destination));
   end Record_Created;

   procedure Record_Created (Destination, Source, Identity, Tree_Revision : String) is
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Destination);
         String'Output (Stream, Source);
         String'Output (Stream, Identity);
         String'Output (Stream, Tree_Revision);
      end Write;
   begin
      if Length (Current) = 0
        or else not Creation_Snapshot_Matches (Destination, Identity, Tree_Revision)
      then
         return;
      end if;
      if Destination'Length > Max_Record_Path_Length
        or else Source'Length > Max_Record_Path_Length
        or else Identity'Length > Max_Record_Token_Length
        or else Tree_Revision'Length > Max_Record_Token_Length
      then
         return;
      end if;
      Append_Journal_Record ("created", Created_Record_Header, Write'Access);
   exception
      when others =>
         --  Publication already succeeded; retain its normal result even if
         --  this crash-recovery journal cannot be extended.
         null;
   end Record_Created;

   procedure Record_Moved (Destination, Source, Identity : String) is
   begin
      Append_Record ("moved", "files-moved-1", Destination, Source, Identity);
   end Record_Moved;

   procedure Append_Record (Name, Header, Destination, Source, Identity : String) is
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Destination);
         String'Output (Stream, Source);
         String'Output (Stream, Identity);
      end Write;
   begin
      if Length (Current) = 0 then
         return;
      end if;
      if Header'Length > Max_Record_Header_Length
        or else Destination'Length > Max_Record_Path_Length
        or else Source'Length > Max_Record_Path_Length
        or else Identity'Length > Max_Record_Token_Length
      then
         return;
      end if;
      Append_Journal_Record (Name, Header, Write'Access);
   exception
      when others =>
         --  Called after publication: a journal failure must not turn a
         --  completed creation or move into a failed filesystem operation.
         null;
   end Append_Record;

   procedure Read_Records
     (Directory, Name, Header : String;
      Destinations : out Files.Types.String_Vectors.Vector;
      Sources : out Files.Types.String_Vectors.Vector;
      Identities : out Files.Types.String_Vectors.Vector)
   is
      Count : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, Name);
      Input : aliased Files.Lease_Streams.Input_Stream;
      Size : Long_Long_Integer;
   begin
      Destinations.Clear;
      Sources.Clear;
      Identities.Clear;
      if not Valid_Absolute_Path (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
      then
         return;
      end if;
      Size := Files.Lease_Streams.Size (Input);
      if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes)
      then
         Files.Lease_Streams.Release (Input);
         return; --  Older journals have no trustworthy identity snapshot.
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Max_Record_Header_Length) /= Header
      then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      while not Files.Lease_Streams.End_Of_Stream (Input) loop
         if Count = Max_Journal_Records then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         declare
            Destination : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Source      : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Identity    : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Token_Length);
         begin
            if not Valid_Absolute_Path (Destination)
              or else not Valid_Absolute_Path (Source)
              or else Identity = ""
              or else not Nul_Free (Identity)
            then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            Destinations.Append (To_Unbounded_String (Destination));
            Sources.Append (To_Unbounded_String (Source));
            Identities.Append (To_Unbounded_String (Identity));
            Count := Count + 1;
         end;
      end loop;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
   end Read_Records;

   procedure Read_Created
     (Directory : String;
      Destinations, Sources, Identities, Tree_Revisions : out Files.Types.String_Vectors.Vector)
   is
      Count : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, "created");
      Input : aliased Files.Lease_Streams.Input_Stream;
      Size : Long_Long_Integer;
   begin
      Destinations.Clear;
      Sources.Clear;
      Identities.Clear;
      Tree_Revisions.Clear;
      if not Valid_Absolute_Path (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
        or else Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
      then
         return;
      end if;
      Size := Files.Lease_Streams.Size (Input);
      if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes)
      then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Max_Record_Header_Length) /= Created_Record_Header
      then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      while not Files.Lease_Streams.End_Of_Stream (Input) loop
         if Count = Max_Journal_Records then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         declare
            Destination : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Source      : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Identity    : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Token_Length);
            Revision    : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Token_Length);
         begin
            if not Valid_Absolute_Path (Destination)
              or else (Source /= "" and then not Valid_Absolute_Path (Source))
              or else Identity = ""
              or else not Nul_Free (Identity)
              or else not Nul_Free (Revision)
            then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            Destinations.Append (To_Unbounded_String (Destination));
            Sources.Append (To_Unbounded_String (Source));
            Identities.Append (To_Unbounded_String (Identity));
            Tree_Revisions.Append (To_Unbounded_String (Revision));
            Count := Count + 1;
         end;
      end loop;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
   end Read_Created;

   procedure Read_Moved
     (Directory : String;
      Destinations, Sources, Identities : out Files.Types.String_Vectors.Vector) is
   begin
      Read_Records (Directory, "moved", "files-moved-1", Destinations, Sources, Identities);
   end Read_Moved;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String)
   is
      Owner : constant String := Hostkit.Fs.Join (Path, ".files-owner");
      Owner_Temp : constant String := Hostkit.Fs.Join (Path, ".files-owner.tmp");
      Owner_Directory : constant String := Stage_Owner_Directory;
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, "files-stage-owner-1");
         String'Output (Stream, Owner_Directory);
         String'Output (Stream, Identity);
      end Write;
   begin
      if Identity = ""
        or else not Valid_Absolute_Path (Path)
        or else not Valid_Absolute_Path (Record_Directory)
        or else not Valid_Absolute_Path (Owner_Directory)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Publish_Record (Owner_Temp, Owner, Write'Access);
      Write_Stage_Record (Record_Directory, Path, Identity);
   end Register_Stage_Internal;

   procedure Read_Owner
     (Path : String;
      Directory, Identity : out Files.Types.UString;
      Valid : out Boolean)
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Owner : constant String := Hostkit.Fs.Join (Path, ".files-owner");
   begin
      Directory := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      Valid := False;
      if Files.Lease_Streams.Open (Owner, Input) /= Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) > Max_Stage_Metadata_Bytes
      then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Max_Record_Header_Length) =
          "files-stage-owner-1"
      then
         Directory := To_Unbounded_String
           (Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length));
         Identity := To_Unbounded_String
           (Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Token_Length));
         Valid := Length (Identity) > 0
           and then Valid_Absolute_Path (To_String (Directory))
           and then Nul_Free (To_String (Identity))
           and then Files.Lease_Streams.End_Of_Stream (Input);
      end if;
      Files.Lease_Streams.Release (Input);
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         Directory := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         Valid := False;
   end Read_Owner;

   function Owner_Matches
     (Path, Directory, Expected_Identity : String) return Boolean
   is
      Recorded_Directory, Recorded_Identity : Files.Types.UString;
      Valid : Boolean;
   begin
      Read_Owner (Path, Recorded_Directory, Recorded_Identity, Valid);
      return Valid
        and then To_String (Recorded_Directory) = Directory
        and then To_String (Recorded_Identity) = Expected_Identity;
   end Owner_Matches;

   function Discard_Stage (Path : String) return Boolean is
      Directory, Identity : Files.Types.UString;
      Owner_Valid : Boolean;
      Foreground : constant Boolean := Length (Current) = 0;
      Foreground_Index : Natural := 0;
      Record_Directory : Files.Types.UString;
      Removed : Boolean := False;

      procedure Release_Foreground is
      begin
         if not Foreground or else Foreground_Index = 0 then
            return;
         end if;
         if Removed then
            Remove_Record (To_String (Record_Directory));
         end if;
         Foreground_Paths.Delete (Foreground_Index);
         Foreground_Records.Delete (Foreground_Index);
         if Foreground_Paths.Is_Empty and then Files.Process_Jobs.Active (Foreground_Job) then
            Files.Process_Jobs.Clean_Stages (Foreground_Job);
            --  Failed records remain in the transport directory. Releasing the
            --  session launches the normal cleanup helper and retains it for
            --  retry instead of abandoning a foreground stage.
            Files.Process_Jobs.Reset (Foreground_Job);
         end if;
      end Release_Foreground;
   begin
      if Foreground then
         for Index in Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
            if To_String (Foreground_Paths (Index)) = Path then
               Foreground_Index := Index;
               Record_Directory := Foreground_Records (Index);
               exit;
            end if;
         end loop;
         if Foreground_Index = 0 or else not Files.Process_Jobs.Active (Foreground_Job) then
            return False;
         end if;
      end if;
      if not (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path)) then
         Removed := True;
         Release_Foreground;
         return True;
      end if;
      Read_Owner (Path, Directory, Identity, Owner_Valid);
      if Owner_Valid
        and then To_String (Directory) =
          (if Foreground then Files.Process_Jobs.Path (Foreground_Job, "") else To_String (Current))
      then
         Removed := Files.File_System.Delete_Staging_Entry
           (Path, To_String (Identity)).Success;
      end if;
      Release_Foreground;
      return Removed;
   exception
      when others =>
         Release_Foreground;
         return False;
   end Discard_Stage;

   procedure Clean_Stages
     (Directory          : String;
      Owner              : Files.Job_Transports.Lease;
      Discard_Unreadable : Boolean := False)
   is
      Stages : constant String := Hostkit.Fs.Join (Directory, "stages");
      Search : Ada.Directories.Search_Type;
      Item : Ada.Directories.Directory_Entry_Type;
      Records : Files.Types.String_Vectors.Vector;

      procedure Clean_Record (Record_Directory : String) is
         Input : aliased Files.Lease_Streams.Input_Stream;
         Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
         Open_Result : Hostkit.Lease_Files.Open_Outcome;
         Path, Expected : Files.Types.UString;
         Recorded_Directory, Owner_Identity : Files.Types.UString;
         Owner_Valid : Boolean;
         Removed : Boolean := False;
      begin
         if Hostkit.Fs.Is_Link (Record_Directory)
           or else not Ada.Directories.Exists (Record_Directory)
           or else Ada.Directories.Kind (Record_Directory) /= Ada.Directories.Directory
         then
            return;
         end if;
         --  No published data means creation stopped before the staging
         --  pathname could be created, so this empty reservation is disposable.
         if not Ada.Directories.Exists (Data) then
            Remove_Record (Record_Directory);
            return;
         end if;
         if Hostkit.Fs.Is_Link (Data)
           or else Ada.Directories.Kind (Data) /= Ada.Directories.Ordinary_File
         then
            --  A published record is always an ordinary file.  Discard the
            --  record without inspecting an injected object or trusting it
            --  as a pathname.
            Remove_Record (Record_Directory);
            return;
         end if;
         Open_Result := Files.Lease_Streams.Open (Data, Input);
         if Open_Result /= Hostkit.Lease_Files.Opened then
            Files.Lease_Streams.Release (Input);
            if Open_Result = Hostkit.Lease_Files.Refused
              or else Discard_Unreadable
            then
               --  Refused objects (including links and multiply-linked
               --  files) cannot become valid records. Other failures may be
               --  transient, so the bounded worker retains them for retry.
               Remove_Record (Record_Directory);
            end if;
            return;
         elsif Files.Lease_Streams.Size (Input) > Max_Stage_Metadata_Bytes then
            Files.Lease_Streams.Release (Input);
            Remove_Record (Record_Directory);
            return;
         end if;
         begin
            if Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Header_Length) /=
                Stage_Record_Header
            then
               Files.Lease_Streams.Release (Input);
               Remove_Record (Record_Directory);
               return;
            end if;
            Path := To_Unbounded_String
              (Files.Bounded_Streams.Input_String
                 (Input'Access, Max_Record_Path_Length));
            Expected := To_Unbounded_String
              (Files.Bounded_Streams.Input_String
                 (Input'Access, Max_Record_Token_Length));
            if not Files.Lease_Streams.End_Of_Stream (Input) then
               raise Ada.IO_Exceptions.Data_Error;
            end if;
            Files.Lease_Streams.Release (Input);
         exception
            when others =>
               Files.Lease_Streams.Release (Input);
               --  Data is published by atomic replacement and is never
               --  subsequently edited.  Once it can be opened, a truncated
               --  or undecodable stream cannot become valid on a later pass.
               --  Drop only its private journal record; no decoded pathname
               --  is used and no external entry is touched.
               Remove_Record (Record_Directory);
               return;
         end;
         if not Valid_Absolute_Path (To_String (Path))
           or else not Nul_Free (To_String (Expected))
         then
            Remove_Record (Record_Directory);
            return;
         end if;
         if not (Ada.Directories.Exists (To_String (Path))
                 or else Hostkit.Fs.Is_Link (To_String (Path)))
         then
            Remove_Record (Record_Directory);
            return;
         end if;
         if Length (Expected) = 0 then
            --  The write-ahead record may precede finalization. An atomically
            --  published owner marker supplies the creation identity without
            --  trusting the identity currently found at the pathname.
            Read_Owner (To_String (Path), Recorded_Directory, Owner_Identity, Owner_Valid);
            if Owner_Valid and then To_String (Recorded_Directory) = Directory then
               Expected := Owner_Identity;
            end if;
         end if;
         declare
            Name : constant String := Ada.Directories.Simple_Name (To_String (Path));
            Valid : constant Boolean :=
              Name'Length > 12
              and then Name (Name'First .. Name'First + 11) = ".files-work-"
              and then Length (Expected) > 0
              and then not Hostkit.Fs.Is_Link (To_String (Path))
              and then Files.File_Identities.Token (To_String (Path)) = To_String (Expected)
              and then Owner_Matches (To_String (Path), Directory, To_String (Expected));
         begin
            if Valid then
               Removed := Files.File_System.Delete_Staging_Entry
                 (To_String (Path), To_String (Expected)).Success;
            end if;
         end;
         if Removed then
            Remove_Record (Record_Directory);
         end if;
      exception
         when others =>
            Files.Lease_Streams.Release (Input);
            --  Keep only this record for retry; damage cannot hide later
            --  independent records as it could in the append-only journal.
      end Clean_Record;
   begin
      if not Files.Job_Transports.Holds (Owner, Directory) then
         return;
      end if;
      if not Ada.Directories.Exists (Stages) or else Hostkit.Fs.Is_Link (Stages)
        or else Ada.Directories.Kind (Stages) /= Ada.Directories.Directory
      then
         return;
      end if;
      Ada.Directories.Start_Search
        (Search, Stages, "stage-*", [Ada.Directories.Directory => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Records.Append (To_Unbounded_String (Ada.Directories.Full_Name (Item)));
      end loop;
      Ada.Directories.End_Search (Search);
      for Record_Directory of Records loop
         Clean_Record (To_String (Record_Directory));
      end loop;
      begin
         Ada.Directories.Delete_Directory (Stages);
      exception
         when Ada.Directories.Use_Error => null;
      end;
   exception
      when others =>
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others => null;
         end;
   end Clean_Stages;
end Files.Job_Context;
