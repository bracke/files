with Files.Types;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Protocol_Names;
with Hostkit.Fs;
with Files.Name_Parts;

package body Files.IO.Durability is
   use Ada.Strings.Unbounded;

   --  The faults Set_Faults arms, read by every flush: a flush can run on
   --  a transfer's worker while the suite arms the next fault.
   protected Faults is
      procedure Set (Suffix : String; Stage : Boolean);

      --  @return The path ending whose flushes fail, or "".
      function Suffix return String;

      --  @return Whether a stage holding its payload fails its flush.
      function Stage return Boolean;

      --  @return Whether any fault is armed.
      function Armed return Boolean;
   private
      Failing_Suffix : Unbounded_String;
      Failing_Stage  : Boolean := False;
   end Faults;

   protected body Faults is
      procedure Set (Suffix : String; Stage : Boolean) is
      begin
         Failing_Suffix := To_Unbounded_String (Suffix);
         Failing_Stage := Stage;
      end Set;

      function Suffix return String is
      begin
         return To_String (Failing_Suffix);
      end Suffix;

      function Stage return Boolean is
      begin
         return Failing_Stage;
      end Stage;

      function Armed return Boolean is
      begin
         return Failing_Stage or else Length (Failing_Suffix) > 0;
      end Armed;
   end Faults;

   --  Path with every '\' read as '/': a suffix matches on Windows too.
   function Slashed (Path : String) return String is
      Result : String := Path;
   begin
      for Item of Result loop
         if Item = '\' then
            Item := '/';
         end if;
      end loop;
      return Result;
   end Slashed;

   --  Whether the suite has made the flush of Path fail.
   function Faulted (Path : String) return Boolean is
   begin
      if not Faults.Armed then
         return False;
      end if;
      declare
         Suffix : constant String := Slashed (Faults.Suffix);
         Text   : constant String := Slashed (Path);
         Leaf   : constant String := Files.Name_Parts.Leaf_Of (Path);
         Prefix : constant String := Files.Protocol_Names.Recovery_Stage_Prefix;
      begin
         return
           (Suffix'Length > 0
            and then Text'Length >= Suffix'Length
            and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix)
           or else
             (Faults.Stage
              and then Leaf'Length > Prefix'Length
              and then Leaf (Leaf'First .. Leaf'First + Prefix'Length - 1) = Prefix
              --  refusal-safe: a test's fault injection only; it decides
              --  whether to feign a failed sync, never what is kept.
              and then Files.IO.Fs_Primitives.Entry_Exists
                         (Hostkit.Fs.Join (Path, Files.Protocol_Names.Stage_Payload)));
      end;
   end Faulted;

   function Sync_File (Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_File (Path));

   function Sync_Descriptor (Descriptor : Integer; Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_Descriptor (Descriptor));

   function Sync_Directory (Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_Directory (Path));

   --  Walked without recursion: an extracted archive may nest folders far
   --  deeper than a thread's stack would hold one frame each for (Windows
   --  gives the main thread 1 MiB). Folders are listed in the order found,
   --  each one's files flushed as it is listed; then every folder's entries,
   --  last found first, so a folder's children are on the device before
   --  the entry naming it is.
   function Sync_Tree (Path : String) return Hostkit.Durability.Outcome is
      use type Hostkit.Durability.Outcome;
      use type Hostkit.Fs.Entry_Kind;
      Worst   : Hostkit.Durability.Outcome := Hostkit.Durability.Synced;
      Folders : Files.Types.String_Vectors.Vector;
      Next    : Positive := 1;

      procedure Note (Outcome : Hostkit.Durability.Outcome) is
      begin
         if Outcome = Hostkit.Durability.Failed
           or else (Outcome = Hostkit.Durability.Not_Supported and then Worst = Hostkit.Durability.Synced)
         then
            Worst := Outcome;
         end if;
      end Note;
   begin
      if Hostkit.Fs.Is_Link (Path) or else not Files.IO.Fs_Primitives.Directory_Exists (Path) then
         return Sync_File (Path);
      end if;
      Folders.Append (To_Unbounded_String (Path));
      while Next <= Natural (Folders.Length) loop
         declare
            Folder : constant String := To_String (Folders (Next));

            procedure Visit (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
               pragma Unreferenced (Stop);
               Full : constant String := Hostkit.Fs.Join (Folder, Name);
            begin
               if Hostkit.Fs.Is_Link (Full) then
                  null;
               elsif Kind = Hostkit.Fs.Directory_Entry then
                  Folders.Append (To_Unbounded_String (Full));
               elsif Kind = Hostkit.Fs.Ordinary_File_Entry then
                  Note (Sync_File (Full));
               end if;
            end Visit;
         begin
            Files.IO.Fs_Primitives.For_Each_Listed (Folder, Visit'Access);
         end;
         Next := Next + 1;
      end loop;
      for Folder of reverse Folders loop
         Note (Sync_Directory (To_String (Folder)));
      end loop;
      return Worst;
   end Sync_Tree;

   procedure Set_Faults (Suffix : String; Stage : Boolean) is
   begin
      Faults.Set (Suffix, Stage);
   end Set_Faults;

end Files.IO.Durability;
