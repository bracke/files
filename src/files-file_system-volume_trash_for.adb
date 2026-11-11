with Hostkit.Durability;
with Hostkit.Host;
with Hostkit.Process;

separate (Files.File_System)
function Volume_Trash_For (Path : String) return String is
   Uid : Files.Types.Account_Id;

   --  Path's parent; "/" (or a drive root) is its own.
   function Parent_Of (Path : String) return String is
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Path);
   begin
      return (if Parent = "" then Path else Parent);
   end Parent_Of;

   --  The device of Path, or of its nearest existing ancestor.
   function Device_Of (Start : String; Device : out Long_Long_Integer) return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Start);
      Known   : Boolean;
   begin
      loop
         if Files.Fs_Primitives.Directory_Exists (To_String (Current)) then
            Device := Hostkit.Metadata.Device_Id (To_String (Current), Known);
            return Known;
         end if;
         declare
            Up : constant String := Parent_Of (To_String (Current));
         begin
            exit when Up = To_String (Current);
            Current := To_Unbounded_String (Up);
         end;
      end loop;
      return False;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Device_Of;

   --  Base, made usable: created owner-only with files/ and info/ if absent.
   function Prepared (Base : String) return String is
   begin
      Files.Private_Directories.Ensure (Base);
      Files.Private_Directories.Ensure (Hostkit.Fs.Join (Base, "files"));
      Files.Private_Directories.Ensure (Hostkit.Fs.Join (Base, "info"));
      return (if Valid_Volume_Trash_Base (Base) then Base else "");
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return "";
   end Prepared;

   --  Remember Base for the trash view, which lists volume trashes on mounts
   --  the root list does not show too. Best effort: a trash missing from the
   --  list is only missing from the view, still restorable from its volume.
   procedure Remember (Base : String) is
      Data : constant String := Support.Application_Data_Directory;
      App  : constant String := (if Data = "" then "" else Hostkit.Fs.Join (Data, "files"));
      List : constant String := (if App = "" then "" else Hostkit.Fs.Join (App, "volume-trashes"));
      --  This process's own temporary file: background jobs trash too.
      Partial : constant String :=
        List & ".partial-" & Natural_Text (Natural (abs Hostkit.Host.Own_Process_Id));

      --  Replace the list with Known and Base.
      procedure Write (Known : Files.Types.String_Vectors.Vector) is
         File    : Ada.Text_IO.File_Type;
      begin
         Files.Fs_Primitives.Create_Path (App);
         Hostkit.Fs.Create_Text (File, Ada.Text_IO.Out_File, Partial);
         for Item of Known loop
            --  Bounded: the oldest are dropped first.
            if Natural (Known.Length) < Max_Remembered_Volume_Trashes
              or else Item /= Known.First_Element
            then
               Ada.Text_IO.Put_Line (File, To_String (Item));
            end if;
         end loop;
         Ada.Text_IO.Put_Line (File, Base);
         Ada.Text_IO.Close (File);
         --  Its content on the device first, or a crash could leave the list
         --  replaced by an empty one. A list that will not sync is still
         --  better than none: it replaces the old one all the same.
         declare
            Synced : constant Hostkit.Durability.Outcome := Hostkit.Durability.Sync_File (Partial);
            pragma Unreferenced (Synced);
         begin
            null;
         end;
         --  One step that replaces the list, so it is never missing: a
         --  replacing rename on every host, where GNAT's refuses an existing
         --  target on Windows.
         if not Hostkit.Fs.Replace_File (Partial, List) then
            Files.Fs_Primitives.Delete_File (Partial);
         end if;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end Write;
   begin
      if List = "" then
         return;
      end if;
      --  Another process (a background job) may replace the list between
      --  this one's read and its rename, and one of the two additions is
      --  lost: read it back, and write again while Base is missing.
      for Attempt in 1 .. 3 loop
         declare
            Known : constant Files.Types.String_Vectors.Vector := Remembered_Volume_Trashes;
         begin
            exit when Known.Contains (To_Unbounded_String (Base));
            Write (Known);
         end;
      end loop;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
   end Remember;

   Item_Device, Home_Device : Long_Long_Integer;
begin
   if not Volume_Trash_Supported
     or else not Hostkit.Process.Current_User_Account (Uid)
     or else not Device_Of (Files.Fs_Primitives.Parent_Directory (Path), Item_Device)
     or else not Device_Of (Trash_Base_Path, Home_Device)
     or else Item_Device = Home_Device
   then
      return "";
   end if;

   declare
      --  The top of the item's filesystem: the highest ancestor on its device.
      Top : Unbounded_String := To_Unbounded_String (Files.Fs_Primitives.Parent_Directory (Path));
      Id  : constant String := Files.Types.Account_Image (Uid);
   begin
      loop
         declare
            Up     : constant String := Parent_Of (To_String (Top));
            Device : Long_Long_Integer;
            Known  : Boolean;
         begin
            exit when Up = To_String (Top);
            Device := Hostkit.Metadata.Device_Id (Up, Known);
            exit when not Known or else Device /= Item_Device;
            Top := To_Unbounded_String (Up);
         end;
      end loop;

      --  A network mount gets its own trash too: the home trash's would copy
      --  the whole item across the network (a rename on the share is what
      --  the user expects), and the trash view lists it with the others.
      declare
         Shared : constant String := Hostkit.Fs.Join (To_String (Top), ".Trash");
         Chosen : Unbounded_String;
      begin
         --  Checked before anything is made in it: an untrusted .Trash is
         --  not used at all, as the specification says.
         if Safe_Trash_Parent (Shared, Shared => True)
           and then Safe_Trash_Parent (To_String (Top), Shared => False)
         then
            Chosen := To_Unbounded_String (Prepared (Hostkit.Fs.Join (Shared, Id)));
         end if;
         if Length (Chosen) = 0 and then Safe_Trash_Parent (To_String (Top), Shared => False) then
            Chosen := To_Unbounded_String (Prepared (Hostkit.Fs.Join (To_String (Top), ".Trash-" & Id)));
         end if;
         if Length (Chosen) > 0 then
            Remember (To_String (Chosen));
         end if;
         return To_String (Chosen);
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Volume_Trash_For;
