with Ada.Containers.Vectors;
with Ada.Directories;

with Files.Platform.Metadata;

package body Files.Folder_Size is

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   --  Mirror the guards of Files.File_System.Directory_Size so the incremental
   --  walk produces the same totals for the same subtree.
   Max_Entries : constant := 50_000;
   Max_Depth   : constant := 64;

   --  A directory still to be visited, with its depth below the root.
   type Pending_Dir is record
      Path  : Unbounded_String;
      Depth : Natural := 0;
   end record;

   package Pending_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Pending_Dir);

   --  Walk state (one measurement at a time, all on the UI thread).
   Target_Path : Unbounded_String;
   Active      : Boolean := False;
   Root_Valid  : Boolean := False;
   Pending     : Pending_Vectors.Vector;
   Cur_Search  : Ada.Directories.Search_Type;
   Cur_Open    : Boolean := False;
   Cur_Depth   : Natural := 0;
   Acc         : Files.File_System.Directory_Size_Result;
   Visited     : Natural := 0;

   --  Finished result awaiting collection.
   Done        : Boolean := False;
   Done_Path   : Unbounded_String;
   Done_Result : Files.File_System.Directory_Size_Result;

   function Saturating_Long_Add
     (Left  : Long_Long_Integer;
      Right : Long_Long_Integer)
      return Long_Long_Integer is
   begin
      if Right > 0 and then Left > Long_Long_Integer'Last - Right then
         return Long_Long_Integer'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Long_Add;

   function Is_Symlink (Candidate : String) return Boolean is
   begin
      return Files.Platform.Metadata.Symlink_Target_Token (Candidate) /= "";
   exception
      when others =>
         return False;
   end Is_Symlink;

   --  Release the open directory handle, if any.
   procedure Close_Search is
   begin
      if Cur_Open then
         Ada.Directories.End_Search (Cur_Search);
         Cur_Open := False;
      end if;
   end Close_Search;

   --  Publish the accumulated totals as the finished result and go idle.
   --  Available mirrors Directory_Size: True whenever the root was a readable
   --  directory (even when the walk was capped), False otherwise.
   procedure Finish is
   begin
      Close_Search;
      Pending.Clear;
      Acc.Available := Root_Valid;
      Done_Path := Target_Path;
      Done_Result := Acc;
      Done := True;
      Active := False;
   end Finish;

   procedure Request (Path : String) is
   begin
      if Active and then Target_Path = To_Unbounded_String (Path) then
         return;
      end if;

      Close_Search;
      Pending.Clear;
      Target_Path := To_Unbounded_String (Path);
      Acc := (others => <>);
      Visited := 0;
      Cur_Depth := 0;
      Done := False;

      --  Match the top-level guard of Directory_Size: a missing path or a
      --  non-directory yields an unavailable result. The validity captured
      --  here (not re-checked mid-walk) reproduces the reference exactly,
      --  including the race where the root vanishes after this check.
      begin
         Root_Valid :=
           Path /= ""
           and then Ada.Directories.Exists (Path)
           and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
      exception
         when others =>
            Root_Valid := False;
      end;

      Pending.Append (Pending_Dir'(Path => Target_Path, Depth => 0));
      Active := True;
   end Request;

   procedure Cancel is
   begin
      Close_Search;
      Pending.Clear;
      Active := False;
   end Cancel;

   --  Classify one entry exactly as Directory_Size does: count every non-dot
   --  entry, skip symlinks, descend real directories, size ordinary files.
   procedure Process_Entry (Item : Ada.Directories.Directory_Entry_Type) is
      Name : constant String := Ada.Directories.Simple_Name (Item);
      Full : constant String := Ada.Directories.Full_Name (Item);
   begin
      if Name = "." or else Name = ".." then
         return;
      end if;

      Visited := Visited + 1;
      if Visited > Max_Entries then
         Acc.Capped := True;
         return;
      end if;

      Acc.Item_Count := Acc.Item_Count + 1;

      if Is_Symlink (Full) then
         null;
      elsif Ada.Directories.Kind (Item) = Ada.Directories.Directory then
         Pending.Append (Pending_Dir'(Path => To_Unbounded_String (Full), Depth => Cur_Depth + 1));
      elsif Ada.Directories.Kind (Item) = Ada.Directories.Ordinary_File then
         Acc.File_Count := Acc.File_Count + 1;
         Acc.Total_Bytes :=
           Saturating_Long_Add
             (Acc.Total_Bytes,
              Long_Long_Integer (Ada.Directories.Size (Item)));
      end if;
   exception
      when others =>
         --  Skip entries that cannot be classified or sized (races, permission
         --  denials) without aborting the walk, as Directory_Size does.
         null;
   end Process_Entry;

   --  Open the next pending directory into Cur_Search. Directories past the
   --  depth guard are capped and skipped, matching Directory_Size, which sets
   --  Capped on entry to an over-deep Walk.
   procedure Open_Next_Directory is
      Next : constant Pending_Dir := Pending.Last_Element;
   begin
      Pending.Delete_Last;

      if Next.Depth > Max_Depth then
         Acc.Capped := True;
         return;
      end if;

      begin
         Ada.Directories.Start_Search
           (Search    => Cur_Search,
            Directory => To_String (Next.Path),
            Pattern   => "",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => True]);
         Cur_Open := True;
         Cur_Depth := Next.Depth;
      exception
         when others =>
            --  An unreadable subdirectory is skipped, as Directory_Size does.
            Cur_Open := False;
      end;
   end Open_Next_Directory;

   procedure Step (Budget : Natural := 4000) is
      Item     : Ada.Directories.Directory_Entry_Type;
      Consumed : Natural := 0;
   begin
      if not Active then
         return;
      end if;

      while Consumed < Budget loop
         --  Directory_Size unwinds the whole walk once Capped is set (via
         --  "exit when Result.Capped"), so stop here on any cap.
         if Acc.Capped then
            Finish;
            return;
         end if;

         if Cur_Open then
            if Ada.Directories.More_Entries (Cur_Search) then
               Ada.Directories.Get_Next_Entry (Cur_Search, Item);
               Consumed := Consumed + 1;
               Process_Entry (Item);
            else
               Close_Search;
            end if;
         elsif Pending.Is_Empty then
            Finish;
            return;
         else
            Open_Next_Directory;
         end if;
      end loop;
   end Step;

   procedure Take
     (Path      : out Unbounded_String;
      Result    : out Files.File_System.Directory_Size_Result;
      Available : out Boolean) is
   begin
      if Done then
         Path := Done_Path;
         Result := Done_Result;
         Available := True;
         Done := False;
      else
         Path := Null_Unbounded_String;
         Result := (others => <>);
         Available := False;
      end if;
   end Take;

   function Is_Active return Boolean is
   begin
      return Active;
   end Is_Active;

   function Target_For_Test return String is
   begin
      if Active then
         return To_String (Target_Path);
      else
         return "";
      end if;
   end Target_For_Test;

end Files.Folder_Size;
