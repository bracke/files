with Ada.Streams;
with Files.IO.Durable_Writes;
with Hostkit.Process;

separate (Files.File_System.Trash)
function Volume_Trash_For (Path : String) return String is
   Uid : Files.Types.Account_Id;

   --  Path's parent; "/" (or a drive root) is its own.
   function Parent_Of (Path : String) return String is
      Parent : constant String := Files.IO.Fs_Primitives.Parent_Directory (Path);
   begin
      return (if Parent = "" then Path else Parent);
   end Parent_Of;

   --  The device of Path, or of its nearest existing ancestor.
   function Device_Of (Start : String; Device : out Long_Long_Integer) return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Start);
      Known   : Boolean;
   begin
      loop
         if Files.IO.Fs_Primitives.Directory_Exists (To_String (Current)) then
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

   --  Base, made usable: created owner-only, with files/ and info/ for a
   --  freedesktop trash (the Finder's keeps its items in Base itself).
   function Prepared (Base : String) return String is
   begin
      Files.IO.Private_Directories.Ensure (Base);
      if not Is_Finder_Volume_Trash (Base) then
         Files.IO.Private_Directories.Ensure (Hostkit.Fs.Join (Base, "files"));
         Files.IO.Private_Directories.Ensure (Trash_Info_Directory (Base));
      end if;
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
      List : constant String := Volume_Trash_List_Path;

      --  Replace the list with Known and Base, published whole: written to
      --  a temporary of this process's own (background jobs trash too) and
      --  renamed over the list once its content is on the device, so a
      --  crash leaves the old list or the new one, never an empty one. A
      --  list that will not sync is not published; one published whose
      --  folder will not sync (Published_Not_Durable) is kept.
      procedure Write (Known : Files.Types.String_Vectors.Vector) is
         procedure Lines (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
         begin
            for Item of Known loop
               --  Bounded: the oldest are dropped first.
               if Natural (Known.Length) < Max_Remembered_Volume_Trashes
                 or else Item /= Known.First_Element
               then
                  String'Write (Stream, To_String (Item) & ASCII.LF);
               end if;
            end loop;
            String'Write (Stream, Base & ASCII.LF);
         end Lines;

         Temporary : Files.Types.UString;
         Identity  : Files.Types.UString;
      begin
         Files.IO.Fs_Primitives.Create_Path (Support.Files_Data_Directory);
         --  A temporary a crash left before this process started goes first.
         Files.IO.Durable_Writes.Sweep_Stale_Temporaries (List);
         Files.IO.Durable_Writes.Write_Private_Temporary (List, Lines'Access, Temporary, Identity);
         case Files.IO.Durable_Writes.Publish (To_String (Temporary), List) is
            when Files.IO.Durable_Writes.Published_Durable | Files.IO.Durable_Writes.Published_Not_Durable =>
               null;
            when Files.IO.Durable_Writes.Not_Published =>
               Files.IO.Durable_Writes.Remove_Owned (To_String (Temporary), To_String (Identity));
         end case;
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
            Complete : Boolean;
            Known    : constant Files.Types.String_Vectors.Vector := Remembered_Volume_Trashes (Complete);
         begin
            --  A list that could not be read is left as it is: written from
            --  what was read, it would forget every other volume's trash.
            exit when not Complete or else Known.Contains (To_Unbounded_String (Base));
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
     or else not Device_Of (Files.IO.Fs_Primitives.Parent_Directory (Path), Item_Device)
     or else not Device_Of (Trash_Base_Path, Home_Device)
     or else Item_Device = Home_Device
   then
      return "";
   end if;

   declare
      --  The top of the item's filesystem: the highest ancestor on its device.
      Top : Unbounded_String := To_Unbounded_String (Files.IO.Fs_Primitives.Parent_Directory (Path));
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
         Finder : constant String := Hostkit.Fs.Join (To_String (Top), ".Trashes");
         Chosen : Unbounded_String;
      begin
         --  The Finder's layout, where the home trash is ~/.Trash: the
         --  volume's root-owned, sticky .Trashes (the system makes it) holds
         --  a folder per user, its items directly in it, as the Finder lists
         --  and empties them. No .Trashes the system made, or one that is
         --  not safe, and the item is copied to the home trash as before:
         --  a freedesktop trash there would be one the Finder never shows.
         if Trash_Backend_Of_Current_Environment = Trash_Macos_Home then
            if Safe_Trash_Parent (Finder, Shared => True)
              and then Safe_Trash_Parent (To_String (Top), Shared => False)
            then
               Chosen := To_Unbounded_String (Prepared (Hostkit.Fs.Join (Finder, Id)));
            end if;
            if Length (Chosen) > 0 then
               Remember (To_String (Chosen));
            end if;
            return To_String (Chosen);
         end if;
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
