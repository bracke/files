separate (Files.File_System)
function Evaluate_Native_Trash
  (Request : Native_Trash_Request)
   return Native_Trash_Result is
begin
   case Request.Backend is
      when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
         --  The desktop's own trash, described by the host rather than by a
         --  per-OS body of ours: Hostkit says whether there is one here.
         declare
            --  Only a build for that desktop can reach its trash.
            Is_Target : constant Boolean :=
              Hostkit.Host.Current =
                (if Request.Backend = Trash_Windows_Recycle_Bin then Hostkit.Host.Windows else Hostkit.Host.MacOS);
            Usable : constant Boolean := Is_Target and then Hostkit.Trash.Current.Available;
         begin
            --  "native_unavailable" and not "unavailable": the desktop trash is
            --  not reachable in this build, which is a different thing from
            --  this environment having no trash at all -- the caller still has
            --  the freedesktop path.
            return
              (Supported => Usable,
               Attempted => False,
               Completed => False,
               Error_Key =>
                 (if Usable
                  then Null_Unbounded_String
                  else To_Unbounded_String ("error.trash.native_unavailable")));
         end;
      when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
         return (Supported => True, Attempted => False, Completed => False, Error_Key => Null_Unbounded_String);
      when Trash_Unavailable =>
         return
           (Supported => False,
            Attempted => False,
            Completed => False,
            Error_Key => To_Unbounded_String ("error.trash.unavailable"));
   end case;
end Evaluate_Native_Trash;
