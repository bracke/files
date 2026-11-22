with Hostkit.Fs;
with Hostkit.Metadata_Copy;
separate (Files.File_System.Copying)
procedure Copy_Node
  (Source_Path      : String;
   Destination_Path : String;
   Depth            : Natural;
   Walk             : in out Copy_Walk)
is
   Times                  : Source_Time_Maps.Map renames Walk.Times;
   Preserve_Ownership     : Boolean renames Walk.Preserve_Ownership;
   Copied_Files           : Copied_File_Maps.Map renames Walk.Copied_Files;
   --  Only the root's own bytes are digested.
   Wants_Digest           : constant Boolean := Walk.Want_Root_Digest and then Depth = 0;
   --  A copy of a folder that (directly or transitively) contains a symlink to
   --  an ancestor would, without this cap, recurse until the path exceeds
   --  PATH_MAX. The symlink guard below removes that cause; this is a defensive
   --  backstop far beyond any real directory nesting. Reaching it raises, which
   --  fails the whole copy (see the function wrapper) rather than silently
   --  truncating -- important because a cross-device MOVE deletes the source
   --  only after a successful copy.
   Max_Copy_Depth : constant := 1024;

   State     : Node_State;
   Owned     : Boolean renames State.Owned;

   Metadata : Hostkit.Metadata_Copy.Snapshot := Hostkit.Metadata_Copy.No_Snapshot;
   Source_Identity : Files.Types.UString renames State.Source_Identity;
   Source_Revision : Files.Types.UString renames State.Source_Revision;
   Source_Content_Digest : Files.Types.UString;
   Track_Hard_Link : Boolean renames State.Track_Hard_Link;
   Copied_Bytes_Digest : Files.Types.UString renames State.Copied_Digest;

   procedure Copy_Metadata is separate;

   procedure Record_Hard_Link is separate;

   procedure Copy_Entry (Name : String) is
   begin
      Copy_Node (Hostkit.Fs.Join (Source_Path, Name), Hostkit.Fs.Join (Destination_Path, Name), Depth + 1, Walk);
   end Copy_Entry;

begin
   Check_Cancelled (Walk);
   if Wants_Digest then
      Walk.Root_Digest := Null_Unbounded_String;
   end if;
   --  Capture before reading bytes or enumerating children changes atime.
   declare
   begin
      Metadata := Hostkit.Metadata_Copy.Capture (Source_Path);
      if not Hostkit.Metadata_Copy.Is_Available (Metadata) then
         raise Ada.Directories.Use_Error;
      end if;
      if Times.Contains (Source_Path) then
         declare
            Saved_Times : constant Copy_Times := Times.Element (Source_Path);
         begin
            Hostkit.Metadata_Copy.Set_Times (Metadata, Saved_Times);
         end;
      end if;
   end;
   --  Preserve a symlink as a link instead of following it. Ada.Directories.Kind
   --  dereferences links, so classifying by it would copy the link's *target*
   --  (losing the link, or -- for a link to an ancestor -- exploding into an
   --  unbounded recursive copy). Recreate the link verbatim and stop. This
   --  mirrors the search/size walkers, which also skip links via Hostkit.Fs.
   if Hostkit.Fs.Is_Link (Source_Path)
     or else Files.IO.Fs_Primitives.Kind (Source_Path) = Ada.Directories.Ordinary_File
   then
      if Copy_Hard_Link (Source_Path, Destination_Path, Walk, Metadata, Wants_Digest, State) then
         return;
      end if;
   end if;
   if Hostkit.Fs.Is_Link (Source_Path) then
      declare
         Target  : Ada.Strings.Unbounded.Unbounded_String;
         Created : Boolean := False;
      begin
         if Hostkit.Fs.Read_Link_Target (Source_Path, Target) then
            Files.IO.Errors.Clear_Os_Error;
            Created := Hostkit.Fs.Create_Link (To_String (Target), Destination_Path);
            if not Created then
               Files.IO.Errors.Capture;
            end if;
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

   case Files.IO.Fs_Primitives.Kind (Source_Path) is
      when Ada.Directories.Directory =>
         begin
            Files.IO.Errors.Clear_Os_Error;
            Files.IO.Fs_Primitives.Create_Directory (Destination_Path);
         exception
            when others =>
               Files.IO.Errors.Capture;
               raise;
         end;
         Owned := True;
         For_Each_Entry (Source_Path, Copy_Entry'Access);
      when Ada.Directories.Ordinary_File =>
         Copy_File_Bytes
           (Source_Path, Destination_Path, Walk, Wants_Digest, Hostkit.Metadata_Copy.Is_Encrypted (Metadata), State);
      when Ada.Directories.Special_File =>
         --  Opening a FIFO or device can block without a cancellation point.
         raise Ada.Directories.Use_Error;
   end case;
   Check_Cancelled (Walk);
   --  Apply attributes and times after children have been copied.
   --  Metadata failure aborts staging, so a move never discards its source.
   Copy_Metadata;
   Record_Hard_Link;
exception
   when others =>
      Metadata := Hostkit.Metadata_Copy.No_Snapshot;
      if Owned then
         begin
            Delete_Owned_Tree (Destination_Path);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
         end;
      end if;
      raise;
end Copy_Node;
