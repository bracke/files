separate (Files.File_System)
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result is
   begin
      case Request.Backend is
         when Trash_Windows_Recycle_Bin =>
            return Files.Platform.Windows.Evaluate_Trash (Request);
         when Trash_Macos_Native =>
            return Files.Platform.Macos.Evaluate_Trash (Request);
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
