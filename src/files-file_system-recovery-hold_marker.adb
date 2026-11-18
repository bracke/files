separate (Files.File_System.Recovery)
   function Hold_Marker
     (Stage, Name : String;
      Item        : in out Hostkit.Lease_Files.Lease)
      return Boolean
   is
      Path : constant String := Hostkit.Fs.Join (Stage, Name);
   begin
      case Hostkit.Lease_Files.Create (Path, Item) is
         when Hostkit.Lease_Files.Opened =>
            if not Hostkit.Lease_Files.Write_At (Item, Marker_Content) then
               raise Ada.Directories.Use_Error;
            end if;
            --  Making the marker's name durable is best effort. A refused
            --  stage sync must not stop the payload leaving: Preserve's
            --  put-back runs exactly when its stage would not sync, and
            --  must still move the original back. A marker lost to a crash
            --  only leaves an emptied stage the sweep will not touch -- a
            --  leftover folder, never a lost payload.
            declare
               Synced : constant Hostkit.Durability.Outcome := Files.Durability.Sync_Directory (Stage);
               pragma Unreferenced (Synced);
            begin
               null;
            end;
            return True;
         when Hostkit.Lease_Files.Busy =>
            return False;
         when others =>
            --  It exists already (POSIX refuses the create, Windows reports
            --  an error): left by a stopped operation, or held by a live one.
            if Files.Fs_Primitives.Entry_Is_Absent (Path) then
               raise Ada.Directories.Use_Error;
            end if;
            case Hostkit.Lease_Files.Open (Path, Hostkit.Lease_Files.Exclusive, True, Item) is
               when Hostkit.Lease_Files.Opened =>
                  return True;
               when Hostkit.Lease_Files.Busy =>
                  return False;
               when others =>
                  raise Ada.Directories.Use_Error;
            end case;
      end case;
   exception
      when others => Hostkit.Lease_Files.Release (Item); raise;
   end Hold_Marker;
