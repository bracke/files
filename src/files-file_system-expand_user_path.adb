separate (Files.File_System)
function Expand_User_Path (Path : String) return String is
   function Home return String is
   begin
      return Hostkit.Fs.Home_Directory;
   exception
      when others =>
         return "";
   end Home;
begin
   if Path = "~" then
      return (if Home = "" then Path else Home);
   elsif Path'Length >= 2
     and then Path (Path'First) = '~'
     and then
       (Path (Path'First + 1) = '/'
        or else
          (Hostkit.Host.Current = Hostkit.Host.Windows
           and then Path (Path'First + 1) = '\'))
   then
      return
        (if Home = "" then Path
         else Home & Path (Path'First + 1 .. Path'Last));
   else
      return Path;
   end if;
end Expand_User_Path;
