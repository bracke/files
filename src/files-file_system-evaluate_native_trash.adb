separate (Files.File_System)
function Evaluate_Native_Trash
  (Request : Native_Trash_Request)
   return Native_Trash_Result is
begin
   case Request.Backend is
      when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
         --  The desktop's own trash, described by the host rather than by a
         --  per-OS body of ours: Hostkit says whether there is one here, what
         --  call is behind it and what it does to the item.
         declare
            --  "This host has no trash" and "this adapter is not what the
            --  build targets" are different answers, and only the second one
            --  is true of the Recycle Bin on a Linux build. Keep them apart:
            --  the per-OS stubs used to, by existing separately.
            Is_Target : constant Boolean :=
              Files_Config.Alire_Host_OS =
                (if Request.Backend = Trash_Windows_Recycle_Bin then "windows" else "macos");
            Facility : constant Hostkit.Trash.Facility := Hostkit.Trash.Current;
            Usable   : constant Boolean := Is_Target and then Facility.Available;
         begin
            return
              (Supported        => Usable,
               Attempted        => False,
               Completed        => False,
               Native_Binding_Available => Usable,
               Native_Binding_Status =>
                 (if not Is_Target then Native_API_Not_Target
                  elsif Facility.Available then Native_API_Binding_Available
                  else Native_API_Binding_Missing),
               Binding_Unit    => To_Unbounded_String ("Hostkit.Trash"),
               Desktop_Standard => False,
               Would_Delete     => False,
               Uses_Recycle_Bin => Request.Backend = Trash_Windows_Recycle_Bin,
               Adapter_Name     =>
                 To_Unbounded_String
                   ((if Request.Backend = Trash_Windows_Recycle_Bin
                     then "windows.recycle_bin" else "macos.native_trash")),
               Native_Api_Name  =>
                 (if Is_Target and then Facility.Api_Name /= Null_Unbounded_String
                  then Facility.Api_Name
                  elsif Request.Backend = Trash_Windows_Recycle_Bin
                  then To_Unbounded_String ("SHFileOperationW")
                  else To_Unbounded_String ("NSFileManager.trashItemAtURL")),
               Operation_Name   => To_Unbounded_String ("move_to_trash"),
               --  What that trash does to an item is a property of the trash,
               --  not of whether this build targets it -- the report describes
               --  the adapter on every host, and only Api_Name below comes from
               --  the live facility. Both desktop trashes keep the item intact
               --  and neither puts a prompt in front of the user.
               Requires_User_Consent => False,
               Preserves_Metadata    => True,
               --  "native_unavailable" and not "unavailable": the desktop
               --  trash is not reachable in this build, which is a different
               --  thing from this environment having no trash at all -- the
               --  caller still has the freedesktop path.
               Error_Key        =>
                 (if Usable
                  then Null_Unbounded_String
                  else To_Unbounded_String ("error.trash.native_unavailable")));
         end;
      when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
         return
           (Supported        => True,
            Attempted        => False,
            Completed        => False,
            Native_Binding_Available => False,
            Native_Binding_Status => Native_API_Binding_Missing,
            Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
            Desktop_Standard => Request.Backend /= Trash_Macos_Home,
            Would_Delete     => False,
            Uses_Recycle_Bin => False,
            Adapter_Name     =>
              To_Unbounded_String
                ((if Request.Backend = Trash_Macos_Home then "macos.home_trash" else "xdg.trash")),
            Native_Api_Name  =>
              To_Unbounded_String
                ((if Request.Backend = Trash_Macos_Home then "filesystem.rename" else "freedesktop.trash")),
            Operation_Name   => To_Unbounded_String ("move_to_trash"),
            Requires_User_Consent => False,
            Preserves_Metadata    => True,
            Error_Key        => Null_Unbounded_String);
      when Trash_Unavailable =>
         return
           (Supported        => False,
            Attempted        => False,
            Completed        => False,
            Native_Binding_Available => False,
            Native_Binding_Status => Native_API_Binding_Missing,
            Binding_Unit    => To_Unbounded_String ("none"),
            Desktop_Standard => False,
            Would_Delete     => False,
            Uses_Recycle_Bin => False,
            Adapter_Name     => To_Unbounded_String ("none"),
            Native_Api_Name  => To_Unbounded_String ("none"),
            Operation_Name   => To_Unbounded_String ("none"),
            Requires_User_Consent => False,
            Preserves_Metadata    => False,
            Error_Key        => To_Unbounded_String ("error.trash.unavailable"));
   end case;
end Evaluate_Native_Trash;
