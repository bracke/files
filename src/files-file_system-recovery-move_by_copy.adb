separate (Files.File_System.Recovery)
   function Move_By_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := Job_Cancelled;
      Batch               : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session;
      If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
      After_Copy          : Copy_Hook := null;
      Expected_Identity   : String := "")
      return Mutation_Result
   is
      Copied : Boolean := False;
      --  What the source checks stop for: the job's cancellation, unless the
      --  caller wants none (a restore must finish once it has begun). Cancel
      --  itself governs the copy.
      Check  : constant Cancellation_Check := (if Cancel = null then null else Job_Cancelled);

      --  The published copy, once the source cannot be removed: taken back
      --  against the revision published, so anything added to it since is
      --  never deleted, or kept where If_Source_Stays says so.
      procedure Discard_Copy is
      begin
         Copy_Kept :=
           If_Source_Stays = Keep_Both
           or else not Delete_Created_Entry (Destination, To_String (Identity), To_String (Revision)).Success;
      end Discard_Copy;
   begin
      Identity := Null_Unbounded_String;
      Revision := Null_Unbounded_String;
      Copy_Kept := False;
      declare
         --  The source is read once, by the copy: a root file's content is
         --  pinned by the digest of the bytes copied, not hashed beforehand.
         --  Where change times are weak every file is pinned by content (see
         --  Support.Snapshot), which only a full snapshot taken now can do.
         Weak_Change_Time : constant Boolean := Support.Weak_Change_Times (Source);
         Shape     : constant Support.Source_Snapshot :=
           Support.Snapshot
             (Source,
              Content      => Weak_Change_Time,
              Cancel       => Check,
              Change_Times =>
                (if Weak_Change_Time then Support.Distrust_Change_Times else Support.Trust_Change_Times));
         Digest    : aliased Files.Types.UString;
         Set_Aside : Boolean;
      begin
         if Expected_Identity /= "" and then To_String (Shape.Root_Identity) /= Expected_Identity then
            return (Success => False, Error_Key => To_Unbounded_String (Fallback_Key));
         end if;
         Support.Copy_To_New_Path
           (Source, Destination, Identity, Revision, Cancel, Shape.Times,
            Purpose => Support.For_Move, Batch => Batch, Root_Digest => Digest'Access);
         Copied := True;
         if After_Copy /= null then
            After_Copy (Source);
         end if;
         --  The source goes next; the copy must be on the device first. Its
         --  files were flushed as they were written; its folders are now.
         if not Support.Sync_Copy (Source, Destination, Files_Too => False) then
            raise Ada.Directories.Use_Error;
         end if;
         declare
            Expected : constant Support.Source_Snapshot :=
              (if Weak_Change_Time then Shape else Support.With_Root_Content (Shape, To_String (Digest)));
            Removed : constant Mutation_Result :=
              Remove_Move_Source (Source, Expected, Fallback_Key, Set_Aside, Check);
         begin
            if not Removed.Success then
               if Set_Aside then
                  Copy_Kept := True;
               else
                  Discard_Copy;
               end if;
            end if;
            return Removed;
         end;
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         declare
            --  Why it failed, before discarding the copy can say otherwise.
            Failed : constant Mutation_Result :=
              (Success => False, Error_Key => Files.Io_Errors.Error_Key (Fallback_Key));
         begin
            --  A failed copy cleans up after itself; one that completed is ours.
            if Copied then
               Discard_Copy;
            end if;
            return Failed;
         end;
   end Move_By_Copy;
