with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded;
with System;

with GNAT.OS_Lib;
with GNAT.Directory_Operations;
with Files.Job_Context;
with Files.File_Identities;
with CryptoLib.Hashes;

with Hostkit.Fs;
with Hostkit.Metadata;

package body Files.File_System.Support is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_long_long;
   use type System.Address;

   procedure For_Each_Entry
     (Path : String; Visit : not null access procedure (Name : String))
   is
      Dir : GNAT.Directory_Operations.Dir_Type;
      type Name_Buffer is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Name_Buffer);
      Buffer : Name_Buffer := new String (1 .. 65_536);
      Last : Natural;
      Names : Files.Types.String_Vectors.Vector;
   begin
      GNAT.Directory_Operations.Open (Dir, Path);
      loop
         GNAT.Directory_Operations.Read (Dir, Buffer.all, Last);
         exit when Last = 0;
         if Last = Buffer'Last then
            raise Ada.Directories.Use_Error;
         end if;
         if Buffer (1 .. Last) /= "." and then Buffer (1 .. Last) /= ".." then
            Names.Append (To_Unbounded_String (Buffer (1 .. Last)));
         end if;
      end loop;
      GNAT.Directory_Operations.Close (Dir);
      Free (Buffer);
      --  Recursion retains neither a large stack buffer nor an open directory.
      for Name of Names loop
         Visit (To_String (Name));
      end loop;
   exception
      when others =>
         Free (Buffer);
         if GNAT.Directory_Operations.Is_Open (Dir) then
            begin
               GNAT.Directory_Operations.Close (Dir);
            exception
               when others => null;
            end;
         end if;
         raise;
   end For_Each_Entry;

   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean) is
   begin
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
         Started := False;
      end if;
   end Safe_End_Search;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         begin
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   function Safe_Environment_Value
     (Name : String)
      return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Types.To_Lower (Safe_Environment_Value (Name)) = Expected;
   end Environment_Equals;

   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Natural_Text;

   function Create_Stage (Parent : String) return String renames Files.Job_Context.Create_Stage;

   overriding function "=" (Left, Right : Source_Snapshot) return Boolean is
      use type Files.Types.String_Vectors.Vector;
   begin
      return Left.Root_Revision = Right.Root_Revision and then Left.Entries = Right.Entries;
   end "=";

   function Regular_File_Digest (Path : String) return String;

   function Snapshot (Path : String) return Source_Snapshot is
      Result : Source_Snapshot;
      package Sorting is new Files.Types.String_Vectors.Generic_Sorting;
      procedure Visit (Full_Path, Relative : String; Depth : Natural) is
         function Capture_Times (Name, Values : System.Address) return Interfaces.C.int
           with Import, Convention => C, External_Name => "files_copy_times_capture";
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Full_Path);
         Saved_Times : aliased Copy_Times;
         Identity : constant String := Files.File_Identities.Token (Full_Path);
         Is_Directory : constant Boolean :=
           not Hostkit.Fs.Is_Link (Full_Path)
           and then Ada.Directories.Kind (Full_Path) = Ada.Directories.Directory;
         Revision : constant String := Files.File_Identities.Revision
           (Full_Path, Depth /= 0 and then not Is_Directory);
         Is_Regular_File : constant Boolean :=
           not Is_Directory and then not Hostkit.Fs.Is_Link (Full_Path)
           and then Ada.Directories.Kind (Full_Path) = Ada.Directories.Ordinary_File;
         procedure Child (Name : String) is
         begin
            Visit (Join_Path (Full_Path, Name), Relative & "/" & Name, Depth + 1);
         end Child;
      begin
         if Identity = "" or else Revision = "" or else Depth > 1_024
           or else Natural (Result.Entries.Length) >= 1_000_000 or else Files.Job_Context.Cancelled
         then
            raise Ada.Directories.Use_Error;
         end if;
         if Capture_Times (Name'Address, Saved_Times'Address) /= 1 then
            raise Ada.Directories.Use_Error;
         end if;
         Result.Times.Insert (Full_Path, Saved_Times);
         declare
            Digest : constant String :=
              (if Is_Regular_File then Regular_File_Digest (Full_Path) else "");
         begin
            if Is_Regular_File
              and then (Files.File_Identities.Token (Full_Path) /= Identity
                or else Files.File_Identities.Revision
                  (Full_Path, Depth /= 0) /= Revision)
            then
               raise Ada.Directories.Use_Error;
            end if;
            Result.Entries.Append (To_Unbounded_String
              (Natural'Image (Relative'Length) & ":" & Relative & Identity & Revision & Digest));
         end;
         if Is_Directory then
            For_Each_Entry (Full_Path, Child'Access);
         end if;
      end Visit;
   begin
      Result.Root_Revision := To_Unbounded_String (Files.File_Identities.Revision (Path));
      if Length (Result.Root_Revision) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Visit (Path, "", 0);
      Sorting.Sort (Result.Entries);
      return Result;
   end Snapshot;

   function Regular_File_Digest (Path : String) return String is
      use Ada.Streams;
      use type GNAT.OS_Lib.File_Descriptor;
      function Open_Noatime (Name : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_digest_open_noatime";
      Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      Input : Ada.Streams.Stream_IO.File_Type;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer : Stream_Element_Array (1 .. 65_536);
      Last : Stream_Element_Offset;
      Bytes_Read : Integer;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);
   begin
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      Descriptor := GNAT.OS_Lib.File_Descriptor (Open_Noatime (Name'Address));
      if Descriptor /= GNAT.OS_Lib.Invalid_FD then
         loop
            if Files.Job_Context.Cancelled then
               raise Ada.Directories.Use_Error;
            end if;
            Bytes_Read := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, Integer (Buffer'Length));
            if Bytes_Read < 0 then
               raise Ada.Directories.Use_Error;
            end if;
            exit when Bytes_Read = 0;
            CryptoLib.Hashes.Update
              (Context, Buffer (Buffer'First .. Buffer'First + Stream_Element_Offset (Bytes_Read) - 1));
         end loop;
         GNAT.OS_Lib.Close (Descriptor);
         Descriptor := GNAT.OS_Lib.Invalid_FD;
      else
         Ada.Streams.Stream_IO.Open (Input, Ada.Streams.Stream_IO.In_File, Path);
         while not Ada.Streams.Stream_IO.End_Of_File (Input) loop
            if Files.Job_Context.Cancelled then
               raise Ada.Directories.Use_Error;
            end if;
            Ada.Streams.Stream_IO.Read (Input, Buffer, Last);
            if Last >= Buffer'First then
               CryptoLib.Hashes.Update (Context, Buffer (Buffer'First .. Last));
            end if;
         end loop;
         Ada.Streams.Stream_IO.Close (Input);
      end if;
      Digest := CryptoLib.Hashes.Finalize (Context);
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
   exception
      when others =>
         Safe_Close (Input);
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         raise;
   end Regular_File_Digest;

   function Tree_Revision (Path : String) return String is
      use Ada.Streams;
      State : Source_Snapshot;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);

      procedure Add (Text : String) is
         Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
      begin
         for Index in Text'Range loop
            Data (Stream_Element_Offset (Index - Text'First + 1)) := Character'Pos (Text (Index));
         end loop;
         if Data'Length > 0 then
            CryptoLib.Hashes.Update (Context, Data);
         end if;
      end Add;

      procedure Restore_Directory_Times is
         function Apply_Times (Name, Values : System.Address) return Interfaces.C.int
           with Import, Convention => C, External_Name => "files_copy_times_apply";
      begin
         for Cursor in State.Times.Iterate loop
            declare
               Item_Path : constant String := Source_Time_Maps.Key (Cursor);
            begin
               if not Hostkit.Fs.Is_Link (Item_Path)
                 and then Ada.Directories.Kind (Item_Path) = Ada.Directories.Directory
               then
                  declare
                     Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Item_Path);
                     Values : aliased Copy_Times := Source_Time_Maps.Element (Cursor);
                  begin
                     if Apply_Times (Name'Address, Values'Address) /= 1 then
                        raise Ada.Directories.Use_Error;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end Restore_Directory_Times;
   begin
      if Hostkit.Fs.Is_Link (Path) then
         return "";
      end if;
      if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         declare
            Identity : constant String := Files.File_Identities.Token (Path);
            Full_Revision : constant String := Files.File_Identities.Revision (Path);
            Stable_Revision : constant String := Files.File_Identities.Revision (Path, False);
         begin
            if Identity = "" or else Full_Revision = "" or else Stable_Revision = "" then
               return "";
            end if;
            declare
               Digest : constant String := Regular_File_Digest (Path);
            begin
               if Files.File_Identities.Token (Path) /= Identity
                 or else Files.File_Identities.Revision (Path) /= Full_Revision
               then
                  return "";
               end if;
               return "file:" & Stable_Revision & ":" & Digest;
            end;
         end;
      elsif Ada.Directories.Kind (Path) /= Ada.Directories.Directory then
         return "";
      end if;
      State := Snapshot (Path);
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      for Item of State.Entries loop
         declare
            Text : constant String := To_String (Item);
         begin
            Add (Natural_Text (Text'Length) & ":" & Text);
         end;
      end loop;
      Restore_Directory_Times;
      Digest := CryptoLib.Hashes.Finalize (Context);
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
   end Tree_Revision;

   function Move_No_Replace (Source, Destination : String) return Boolean is
      function Prepare (Name, Context : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_directory_rename_begin";
      function Finish (Context : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_directory_rename_finish";
      procedure Release (Context : System.Address)
        with Import, Convention => C, External_Name => "files_directory_rename_release";
      Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
      Context : aliased System.Address := System.Null_Address;
      Moved : Boolean;
      Restored : Interfaces.C.int;
   begin
      if Prepare (Name'Address, Context'Address) /= 1 then
         return False;
      end if;
      Moved := Hostkit.Fs.Move_No_Replace (Source, Destination);
      Restored := Finish (Context);
      if Restored /= 1 then
         --  Restore the original pathname before reporting a refused operation.
         --  If that pathname is occupied, leave the committed payload in place.
         if Moved and then Hostkit.Fs.Move_No_Replace (Destination, Source) then
            Moved := False;
         end if;
         Restored := Finish (Context);
         if Restored /= 1 then
            Release (Context);
         end if;
         Context := System.Null_Address;
         raise Ada.Directories.Use_Error;
      end if;
      Context := System.Null_Address;
      return Moved;
   exception
      when others =>
         if Context /= System.Null_Address then
            Restored := Finish (Context);
            if Restored /= 1 then
               Release (Context);
            end if;
         end if;
         raise;
   end Move_No_Replace;

   procedure Check_Copy_Destination (Source, Destination : String) is
   begin
      if Hostkit.Fs.Is_Link (Source) or else Ada.Directories.Kind (Source) /= Ada.Directories.Directory then
         return;
      end if;
      declare
         Original : constant String := GNAT.OS_Lib.Normalize_Pathname (Source, Resolve_Links => True);
         Identity : constant String := Files.File_Identities.Token (Source);
         Parent : UString := To_Unbounded_String (GNAT.OS_Lib.Normalize_Pathname
           (Ada.Directories.Containing_Directory (Destination), Resolve_Links => True));
      begin
         if Original = "" or else Length (Parent) = 0 then
            raise Ada.Directories.Use_Error;
         end if;
         loop
            if To_String (Parent) = Original
              or else (Identity /= "" and then Files.File_Identities.Token (To_String (Parent)) = Identity)
            then
               raise Ada.Directories.Use_Error;
            end if;
            declare
               Next : constant String := GNAT.OS_Lib.Normalize_Pathname
                 (Join_Path (To_String (Parent), ".."), Resolve_Links => True);
            begin
               if Next = "" then
                  raise Ada.Directories.Use_Error;
               end if;
               exit when Next = To_String (Parent);
               Parent := To_Unbounded_String (Next);
            end;
         end loop;
      end;
   end Check_Copy_Destination;

   function Load_Links (Batch : Files.Copy_Context.Session) return Copied_File_Maps.Map is
      Items : constant Files.Types.String_Vectors.Vector := Files.Copy_Context.Records (Batch);
      Links : Copied_File_Maps.Map;
      Index : Positive := 1;
   begin
      if Natural (Items.Length) mod 6 /= 0 then
         raise Ada.Directories.Use_Error;
      end if;
      while Index <= Items.Last_Index loop
         Links.Insert
           (To_String (Items (Index)),
            (Path                 => Items (Index + 3),
             Identity             => Items (Index + 4),
             Source_Revision      => Items (Index + 1),
             Destination_Revision => Items (Index + 5),
             Content_Digest       => Items (Index + 2)));
         Index := Index + 6;
      end loop;
      return Links;
   end Load_Links;

   procedure Save_Links
     (Batch : Files.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String) is
      Items : Files.Types.String_Vectors.Vector;
   begin
      for Cursor in Links.Iterate loop
         declare
            Item : constant Copied_File := Copied_File_Maps.Element (Cursor);
            Path : constant String := To_String (Item.Path);
            Published : constant String :=
              (if Path = Stage then Destination
               elsif Starts_With (Path, Stage & "/") or else Starts_With (Path, Stage & "\")
               then Destination & Path (Path'First + Stage'Length .. Path'Last)
               else Path);
         begin
            Items.Append (To_Unbounded_String (Copied_File_Maps.Key (Cursor)));
            Items.Append (Item.Source_Revision);
            Items.Append (Item.Content_Digest);
            Items.Append (To_Unbounded_String (Published));
            Items.Append (Item.Identity);
            Items.Append (Item.Destination_Revision);
         end;
      end loop;
      Files.Copy_Context.Save (Batch, Items);
   end Save_Links;

   procedure Copy_Node
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural := 0;
      Cancel           : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean;
      Copied_Files : in out Copied_File_Maps.Map;
      Shared_Batch : Boolean := False;
      Root_File_Digest : access Files.Types.UString := null);

   procedure Copy_To_New_Path
     (Source_Path : String; Destination_Path : String; Cancel : Cancellation_Check := null;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session) is
      Identity : Files.Types.UString;
   begin
      Copy_To_New_Path (Source_Path, Destination_Path, Identity, Cancel,
                        Preserve_Ownership => Preserve_Ownership, Batch => Batch);
   end Copy_To_New_Path;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   is
      Tree_Revision_Value : Files.Types.UString;
   begin
      Copy_To_New_Path
        (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Cancel, Times,
         Preserve_Ownership, Batch);
   end Copy_To_New_Path;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   is
      Stage : UString;
      Links : Copied_File_Maps.Map := Load_Links (Batch);
      Copied_Digest : aliased Files.Types.UString;
   begin
      Identity := Null_Unbounded_String;
      Tree_Revision_Value := Null_Unbounded_String;
      Check_Copy_Destination (Source_Path, Destination_Path);
      Stage := To_Unbounded_String (Create_Stage (Ada.Directories.Containing_Directory (Destination_Path)));
      Copy_Node (Source_Path, Join_Path (To_String (Stage), "payload"), 0, Cancel, True, Times,
                 Preserve_Ownership, Links, Files.Copy_Context.Directory (Batch) /= "",
                 Copied_Digest'Access);
      Identity := To_Unbounded_String (Files.File_Identities.Token (Join_Path (To_String (Stage), "payload")));
      declare
         Payload : constant String := Join_Path (To_String (Stage), "payload");
      begin
         if not Hostkit.Fs.Is_Link (Payload)
           and then Ada.Directories.Kind (Payload) = Ada.Directories.Ordinary_File
         then
            declare
               Revision : constant String := Files.File_Identities.Revision (Payload, False);
            begin
               if Revision /= "" and then Length (Copied_Digest) = 64 then
                  Tree_Revision_Value := To_Unbounded_String
                    ("file:" & Revision & ":" & To_String (Copied_Digest));
               end if;
            end;
         else
            Tree_Revision_Value := To_Unbounded_String (Tree_Revision (Payload));
         end if;
      end;
      --  Never publish an unidentifiable payload: Undo and crash recovery
      --  could not verify it afterward, even if staging succeeded.
      if Length (Identity) = 0
        or else (not Hostkit.Fs.Is_Link (Join_Path (To_String (Stage), "payload"))
          and then Length (Tree_Revision_Value) = 0)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Save_Links (Batch, Links, Join_Path (To_String (Stage), "payload"), Destination_Path);
      if not Move_No_Replace (Join_Path (To_String (Stage), "payload"), Destination_Path) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Job_Context.Record_Created
        (Destination_Path, Source_Path, To_String (Identity), To_String (Tree_Revision_Value));
      --  Publication is complete; leftover staging must not falsify its result.
      declare
         Removed : constant Boolean := Files.Job_Context.Discard_Stage (To_String (Stage));
         pragma Unreferenced (Removed);
      begin
         null;
      exception
         when others => null;
      end;
   exception
      when others =>
         begin
            if Length (Stage) > 0 then
               declare
                  Removed : constant Boolean := Files.Job_Context.Discard_Stage (To_String (Stage));
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            end if;
         exception
            when others => null;
         end;
         raise;
   end Copy_To_New_Path;

   --  Recursively copy a file/directory tree. Used as the cross-device
   --  fallback when Ada.Directories.Rename fails with EXDEV (it cannot move
   --  across filesystems), by both trashing and drag-and-drop moves.
   procedure Copy_Node
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural := 0;
      Cancel           : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean;
      Copied_Files : in out Copied_File_Maps.Map;
      Shared_Batch : Boolean := False;
      Root_File_Digest : access Files.Types.UString := null)
   is
      --  A copy of a folder that (directly or transitively) contains a symlink to
      --  an ancestor would, without this cap, recurse until the path exceeds
      --  PATH_MAX. The symlink guard below removes that cause; this is a defensive
      --  backstop far beyond any real directory nesting. Reaching it raises, which
      --  fails the whole copy (see the function wrapper) rather than silently
      --  truncating -- important because a cross-device MOVE deletes the source
      --  only after a successful copy.
      Max_Copy_Depth : constant := 1024;

      Owned     : Boolean := False;

      function Capture_Metadata (Name : System.Address) return System.Address
        with Import, Convention => C, External_Name => "files_copy_metadata_capture";
      function Apply_Metadata (Data, Name : System.Address; Ownership : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_copy_metadata_apply";
      procedure Set_Times (Data, Values : System.Address)
        with Import, Convention => C, External_Name => "files_copy_metadata_set_times";
      procedure Release_Metadata (Data : System.Address)
        with Import, Convention => C, External_Name => "files_copy_metadata_release";
      function Link_Count (Data : System.Address) return Interfaces.C.unsigned_long_long
        with Import, Convention => C, External_Name => "files_copy_metadata_link_count";
      Metadata : System.Address := System.Null_Address;
      Source_Identity : Files.Types.UString;
      Source_Revision : Files.Types.UString;
      Source_Content_Digest : Files.Types.UString;
      Track_Hard_Link : Boolean := False;

      procedure Check_Cancelled;

      function Content_Digest (Path : String) return String is
         use Ada.Streams;
         Input : Ada.Streams.Stream_IO.File_Type;
         Buffer : Stream_Element_Array (1 .. 65_536);
         Last : Stream_Element_Offset;
         Context : CryptoLib.Hashes.SHA256_Context;
         Digest : CryptoLib.Hashes.SHA256_Digest;
         Hex : constant String := "0123456789abcdef";
         Result : String (1 .. 64);

         procedure Add (Data : Stream_Element_Array) is
         begin
            if Data'Length > 0 then
               CryptoLib.Hashes.Update (Context, Data);
            end if;
         end Add;
      begin
         CryptoLib.Hashes.Initialize_SHA256 (Context);
         if Hostkit.Fs.Is_Link (Path) then
            declare
               Target : UString;
            begin
               if not Hostkit.Fs.Read_Link_Target (Path, Target) then
                  raise Ada.Directories.Use_Error;
               end if;
               declare
                  Text : constant String := To_String (Target);
                  Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
               begin
                  for Index in Text'Range loop
                     Data (Stream_Element_Offset (Index - Text'First + 1)) := Character'Pos (Text (Index));
                  end loop;
                  Add (Data);
               end;
            end;
         else
            Ada.Streams.Stream_IO.Open (Input, Ada.Streams.Stream_IO.In_File, Path);
            while not Ada.Streams.Stream_IO.End_Of_File (Input) loop
               Check_Cancelled;
               Ada.Streams.Stream_IO.Read (Input, Buffer, Last);
               if Last >= Buffer'First then
                  Add (Buffer (Buffer'First .. Last));
               end if;
            end loop;
            Ada.Streams.Stream_IO.Close (Input);
         end if;
         Digest := CryptoLib.Hashes.Finalize (Context);
         for Index in Digest'Range loop
            Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
            Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
         end loop;
         return Result;
      exception
         when others =>
            Safe_Close (Input);
            raise;
      end Content_Digest;

      procedure Copy_Metadata is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Destination_Path);
      begin
         if Apply_Metadata (Metadata, Name'Address, Boolean'Pos (Preserve_Ownership)) /= 1 then
            raise Ada.Directories.Use_Error;
         end if;
         Release_Metadata (Metadata);
         Metadata := System.Null_Address;
      end Copy_Metadata;

      procedure Record_Hard_Link is
      begin
         if Track_Hard_Link then
            if Files.File_Identities.Revision (Source_Path, False) /= To_String (Source_Revision)
              or else Content_Digest (Source_Path) /= To_String (Source_Content_Digest)
            then
               raise Ada.Directories.Use_Error;
            end if;
            declare
               Identity : constant String := Files.File_Identities.Token (Destination_Path);
               Destination_Revision : constant String :=
                 Files.File_Identities.Revision (Destination_Path, False);
               Destination_Digest : constant String := Content_Digest (Destination_Path);
            begin
               if Identity = "" or else Destination_Revision = ""
                 or else Destination_Digest /= To_String (Source_Content_Digest)
               then
                  raise Ada.Directories.Use_Error;
               end if;
               Copied_Files.Insert
                 (To_String (Source_Identity),
                  (Path                 => To_Unbounded_String (Destination_Path),
                   Identity             => To_Unbounded_String (Identity),
                   Source_Revision      => Source_Revision,
                   Destination_Revision => To_Unbounded_String (Destination_Revision),
                   Content_Digest       => Source_Content_Digest));
            end;
         end if;
      end Record_Hard_Link;

      procedure Copy_Entry (Name : String) is
      begin
         Copy_Node (Join_Path (Source_Path, Name), Join_Path (Destination_Path, Name),
                    Depth + 1, Cancel, Check_Job_Cancellation, Times, Preserve_Ownership, Copied_Files, Shared_Batch);
      end Copy_Entry;

      procedure Check_Cancelled is
      begin
         if (Cancel /= null and then Cancel.all)
           or else (Check_Job_Cancellation and then Files.Job_Context.Cancelled)
         then
            raise Program_Error;
         end if;
      end Check_Cancelled;

      function Copy_Hard_Link return Boolean is
         Links : Interfaces.C.unsigned_long_long;
      begin
         Links := Link_Count (Metadata);
         if Shared_Batch or else Links > 1 then
            Source_Identity := To_Unbounded_String (Files.File_Identities.Token (Source_Path));
            Source_Revision := To_Unbounded_String (Files.File_Identities.Revision (Source_Path, False));
            if Length (Source_Identity) = 0 then
               raise Ada.Directories.Use_Error;
            end if;
            Track_Hard_Link := Links > 1 or else Copied_Files.Contains (To_String (Source_Identity));
            if Track_Hard_Link then
               Source_Content_Digest := To_Unbounded_String (Content_Digest (Source_Path));
            end if;
         end if;
         if Length (Source_Identity) > 0 and then Copied_Files.Contains (To_String (Source_Identity)) then
            declare
               First : constant Copied_File := Copied_Files.Element (To_String (Source_Identity));
            begin
               if Files.File_Identities.Revision (Source_Path, False) /= To_String (First.Source_Revision)
                 or else Content_Digest (Source_Path) /= To_String (First.Content_Digest)
                 or else Files.File_Identities.Token (To_String (First.Path)) /= To_String (First.Identity)
                 or else Files.File_Identities.Revision (To_String (First.Path), False)
                   /= To_String (First.Destination_Revision)
                 or else Content_Digest (To_String (First.Path)) /= To_String (First.Content_Digest)
               then
                  raise Ada.Directories.Use_Error;
               end if;
               if not Hostkit.Fs.Create_Hard_Link (To_String (First.Path), Destination_Path) then
                  raise Ada.Directories.Use_Error;
               end if;
               Owned := True;
               if Files.File_Identities.Revision (Source_Path, False) /= To_String (First.Source_Revision)
                 or else Content_Digest (Source_Path) /= To_String (First.Content_Digest)
                 or else Files.File_Identities.Token (To_String (First.Path)) /= To_String (First.Identity)
                 or else Files.File_Identities.Token (Destination_Path) /= To_String (First.Identity)
                 or else Files.File_Identities.Revision (To_String (First.Path), False)
                   /= To_String (First.Destination_Revision)
                 or else Files.File_Identities.Revision (Destination_Path, False)
                   /= To_String (First.Destination_Revision)
                 or else Content_Digest (Destination_Path) /= To_String (First.Content_Digest)
               then
                  raise Ada.Directories.Use_Error;
               end if;
               Check_Cancelled;
               Release_Metadata (Metadata);
               Metadata := System.Null_Address;
               if Root_File_Digest /= null and then not Hostkit.Fs.Is_Link (Source_Path) then
                  Root_File_Digest.all := First.Content_Digest;
               end if;
               return True;
            end;
         end if;
         return False;
      end Copy_Hard_Link;

      procedure Copy_Bytes is
         use Ada.Streams;
         use type GNAT.OS_Lib.File_Descriptor;
         Input  : Ada.Streams.Stream_IO.File_Type;
         Output : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
         Buffer : Stream_Element_Array (1 .. 65_536);
         Last   : Stream_Element_Offset;
         Next   : Stream_Element_Offset;
         Wrote  : Integer;
         Closed : Boolean;
         Sparse : Boolean := False;
         Digest_Context : CryptoLib.Hashes.SHA256_Context;
         Digest : CryptoLib.Hashes.SHA256_Digest;
         Hex : constant String := "0123456789abcdef";
         Digest_Text : String (1 .. 64);
         function Skip_Zeros (Descriptor, Count : Interfaces.C.int) return Interfaces.C.int
           with Import, Convention => C, External_Name => "files_copy_skip_zeros";
         function Finish_Sparse (Descriptor : Interfaces.C.int) return Interfaces.C.int
           with Import, Convention => C, External_Name => "files_copy_finish_sparse";
      begin
         if Root_File_Digest /= null then
            CryptoLib.Hashes.Initialize_SHA256 (Digest_Context);
         end if;
         Ada.Streams.Stream_IO.Open (Input, Ada.Streams.Stream_IO.In_File, Source_Path);
         Output := GNAT.OS_Lib.Create_New_File (Destination_Path, GNAT.OS_Lib.Binary);
         if Output = GNAT.OS_Lib.Invalid_FD then
            raise Ada.Directories.Use_Error;
         end if;
         Owned := True;
         while not Ada.Streams.Stream_IO.End_Of_File (Input) loop
            Check_Cancelled;
            Ada.Streams.Stream_IO.Read (Input, Buffer, Last);
            if Root_File_Digest /= null and then Last >= Buffer'First then
               CryptoLib.Hashes.Update (Digest_Context, Buffer (Buffer'First .. Last));
            end if;
            Next := Buffer'First;
            if Last >= Buffer'First and then (for all Index in Buffer'First .. Last => Buffer (Index) = 0)
              and then Skip_Zeros (Interfaces.C.int (Output), Interfaces.C.int (Last - Buffer'First + 1)) = 1
            then
               Sparse := True;
               Next := Last + 1;
            end if;
            while Next <= Last loop
               Wrote := GNAT.OS_Lib.Write (Output, Buffer (Next)'Address, Integer (Last - Next + 1));
               if Wrote <= 0 then
                  raise Ada.Directories.Use_Error;
               end if;
               Next := Next + Stream_Element_Offset (Wrote);
            end loop;
         end loop;
         Ada.Streams.Stream_IO.Close (Input);
         if Sparse and then Finish_Sparse (Interfaces.C.int (Output)) /= 1 then
            raise Ada.Directories.Use_Error;
         end if;
         GNAT.OS_Lib.Close (Output, Closed);
         Output := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            raise Ada.Directories.Use_Error;
         end if;
         if Root_File_Digest /= null then
            Digest := CryptoLib.Hashes.Finalize (Digest_Context);
            for Index in Digest'Range loop
               Digest_Text ((Index - Digest'First) * 2 + 1) :=
                 Hex (Natural (Digest (Index)) / 16 + 1);
               Digest_Text ((Index - Digest'First) * 2 + 2) :=
                 Hex (Natural (Digest (Index)) mod 16 + 1);
            end loop;
            Root_File_Digest.all := To_Unbounded_String (Digest_Text);
         end if;
         Check_Cancelled;
      exception
         when others =>
            Safe_Close (Input);
            if Output /= GNAT.OS_Lib.Invalid_FD then
               GNAT.OS_Lib.Close (Output);
            end if;
            raise;
      end Copy_Bytes;
   begin
      Check_Cancelled;
      if Root_File_Digest /= null then
         Root_File_Digest.all := Null_Unbounded_String;
      end if;
      --  Capture before reading bytes or enumerating children changes atime.
      declare
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source_Path);
      begin
         Metadata := Capture_Metadata (Name'Address);
         if Metadata = System.Null_Address then
            raise Ada.Directories.Use_Error;
         end if;
         if Times.Contains (Source_Path) then
            declare
               Saved_Times : aliased Copy_Times := Times.Element (Source_Path);
            begin
               Set_Times (Metadata, Saved_Times'Address);
            end;
         end if;
      end;
      --  Preserve a symlink as a link instead of following it. Ada.Directories.Kind
      --  dereferences links, so classifying by it would copy the link's *target*
      --  (losing the link, or -- for a link to an ancestor -- exploding into an
      --  unbounded recursive copy). Recreate the link verbatim and stop. This
      --  mirrors the search/size walkers, which also skip links via Hostkit.Fs.
      if Hostkit.Fs.Is_Link (Source_Path)
        or else Ada.Directories.Kind (Source_Path) = Ada.Directories.Ordinary_File
      then
         if Copy_Hard_Link then
            return;
         end if;
      end if;
      if Hostkit.Fs.Is_Link (Source_Path) then
         declare
            Target  : Ada.Strings.Unbounded.Unbounded_String;
            Created : Boolean := False;
         begin
            if Hostkit.Fs.Read_Link_Target (Source_Path, Target) then
               Created := Hostkit.Fs.Create_Link (To_String (Target), Destination_Path);
            end if;

            --  If the link cannot be recreated (unreadable target, or a host
            --  that refuses link creation, e.g. Windows without the privilege),
            --  raise rather than silently omit it. Copy_Tree is the copy step of
            --  the cross-device MOVE fallback, which deletes the source only
            --  after it returns: silently dropping the link and then deleting
            --  the original would lose it. Raising aborts the copy so the move
            --  keeps the source; the function wrapper maps this to
            --  error.copy.failed.
            if not Created then
               raise Program_Error;
            end if;
            Owned := True;
         end;
         Copy_Metadata;
         Record_Hard_Link;
         return;
      end if;

      if Depth > Max_Copy_Depth then
         --  Backstop only; the message would be caught and mapped to
         --  error.copy.failed by the function wrapper, never shown to the user.
         raise Program_Error;
      end if;

      case Ada.Directories.Kind (Source_Path) is
         when Ada.Directories.Directory =>
            Ada.Directories.Create_Directory (Destination_Path);
            Owned := True;
            For_Each_Entry (Source_Path, Copy_Entry'Access);
         when Ada.Directories.Ordinary_File =>
            Copy_Bytes;
         when Ada.Directories.Special_File =>
            --  Opening a FIFO or device can block without a cancellation point.
            raise Ada.Directories.Use_Error;
      end case;
      Check_Cancelled;
      --  Apply attributes and times after children have been copied.
      --  Metadata failure aborts staging, so a move never discards its source.
      Copy_Metadata;
      Record_Hard_Link;
   exception
      when others =>
         Release_Metadata (Metadata);
         if Owned then
            begin
               Delete_Owned_Tree (Destination_Path);
            exception
               when others => null;
            end;
         end if;
         raise;
   end Copy_Node;

   procedure Copy_Tree
     (Source_Path : String;
      Destination_Path : String;
      Depth : Natural := 0;
      Cancel : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session) is
      Copied_Files : Copied_File_Maps.Map := Load_Links (Batch);
   begin
      Check_Copy_Destination (Source_Path, Destination_Path);
      Copy_Node (Source_Path, Destination_Path, Depth, Cancel, Check_Job_Cancellation, Times,
                 Preserve_Ownership, Copied_Files, Files.Copy_Context.Directory (Batch) /= "");
      Save_Links (Batch, Copied_Files, Destination_Path, Destination_Path);
   end Copy_Tree;

   procedure Delete_Tree (Path : String) is
      procedure Delete_Entry (Name : String) is
      begin
         Delete_Tree (Join_Path (Path, Name));
      end Delete_Entry;
   begin
      --  Unlink a symlink as a link, never following it: Ada.Directories.Kind
      --  and Delete_Tree dereference links, so classifying by Kind would let a
      --  recursive delete walk into and wipe the link target's real contents
      --  (e.g. Shift-Delete of a symlink to ~/Pictures). Mirrors Copy_Tree.
      if Hostkit.Fs.Is_Link (Path) then
         if not Hostkit.Fs.Delete_Link (Path) then
            raise Program_Error;
         end if;
         return;
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            For_Each_Entry (Path, Delete_Entry'Access);
            Ada.Directories.Delete_Directory (Path);
         when Ada.Directories.Ordinary_File | Ada.Directories.Special_File =>
            Ada.Directories.Delete_File (Path);
      end case;
   end Delete_Tree;

   procedure Delete_Owned_Tree (Path : String) is
      Available : Boolean;
      Mode : Natural;
      Lease_Present : Boolean := False;
      procedure Delete_Entry (Name : String) is
      begin
         if Name = ".files-job-owner" then
            Lease_Present := True;
         else
            Delete_Owned_Tree (Join_Path (Path, Name));
         end if;
      end Delete_Entry;
   begin
      if Hostkit.Fs.Is_Link (Path) or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory then
         Delete_Tree (Path);
         return;
      end if;
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         Mode := Hostkit.Metadata.File_Permission_Bits (Path, Available);
         if not Available or else not Hostkit.Metadata.Set_Permissions
           (Path, (Mode mod 8#100#) + 8#700#)
         then
            raise Ada.Directories.Use_Error;
         end if;
      end if;
      For_Each_Entry (Path, Delete_Entry'Access);
      --  Keep the lease available if an earlier child cannot be removed.
      --  After it is removed, only the empty directory remains to delete.
      if Lease_Present then
         Delete_Owned_Tree (Join_Path (Path, ".files-job-owner"));
      end if;
      Ada.Directories.Delete_Directory (Path);
   end Delete_Owned_Tree;

end Files.File_System.Support;
