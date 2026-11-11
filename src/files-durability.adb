with Ada.Strings.Unbounded;
with Files.Fs_Primitives;
with Files.Protocol_Names;
with Hostkit.Fs;

package body Files.Durability is
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
         Leaf   : constant String := Files.Fs_Primitives.Leaf_Text (Path);
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
              and then Files.Fs_Primitives.Entry_Exists (Hostkit.Fs.Join (Path, "payload")));
      end;
   end Faulted;

   function Sync_File (Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_File (Path));

   function Sync_Descriptor (Descriptor : Integer; Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_Descriptor (Descriptor));

   function Sync_Directory (Path : String) return Hostkit.Durability.Outcome is
     (if Faulted (Path) then Hostkit.Durability.Failed else Hostkit.Durability.Sync_Directory (Path));

   procedure Set_Faults (Suffix : String; Stage : Boolean) is
   begin
      Faults.Set (Suffix, Stage);
   end Set_Faults;

end Files.Durability;
