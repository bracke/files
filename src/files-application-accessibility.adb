with Files.Application.Window_Policy;
with Files.Diagnostics;
with Files.Timing;
with Ada.Containers.Ordered_Maps;
with Ada.Real_Time;
with Ada.Containers.Vectors;

with A11ykit;
with Guikit.Draw;

package body Files.Application.Accessibility is

   --  The neutral roles line up one-to-one with the renderer's roles.
   function A11y_Role (Node_Role : Guikit.Draw.Accessibility_Role) return A11ykit.Role is
     (case Node_Role is
         when Guikit.Draw.Role_Window     => A11ykit.Role_Window,
         when Guikit.Draw.Role_Dialog     => A11ykit.Role_Dialog,
         when Guikit.Draw.Role_Pane       => A11ykit.Role_Pane,
         when Guikit.Draw.Role_Toolbar    => A11ykit.Role_Toolbar,
         when Guikit.Draw.Role_Button     => A11ykit.Role_Button,
         when Guikit.Draw.Role_Text_Input => A11ykit.Role_Text_Input,
         when Guikit.Draw.Role_List       => A11ykit.Role_List,
         when Guikit.Draw.Role_List_Item  => A11ykit.Role_List_Item,
         when Guikit.Draw.Role_Table      => A11ykit.Role_Table,
         when Guikit.Draw.Role_Table_Row  => A11ykit.Role_Table_Row,
         when Guikit.Draw.Role_Heading    => A11ykit.Role_Heading,
         when Guikit.Draw.Role_Status     => A11ykit.Role_Status);

   function Tree_Of_Nodes
     (Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector)
      return A11ykit.Tree.Accessibility_Tree
   is
      Flat : A11ykit.Tree.Node_Vectors.Vector;
   begin
      for Node of Nodes loop
         Flat.Append
           (A11ykit.Tree.Node'
              (Node_Role   => A11y_Role (Node.Role),
               Bounds      =>
                 (X      => Node.X,
                  Y      => Node.Y,
                  Width  => Node.Width,
                  Height => Node.Height),
               Name        => Node.Name,
               Description => Node.Description,
               Node_State  =>
                 (Enabled  => Node.Enabled,
                  Selected => Node.Selected,
                  Focused  => Node.Focused,
                  Active   => False),
               Parent      => 0));
      end loop;

      return A11ykit.Tree.Build (Flat);
   end Tree_Of_Nodes;

   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree is (Tree_Of_Nodes (Frame.Accessibility));

   --  Each open window's last tree, and which one has the focus. The screen
   --  reader is given them as one tree, the windows side by side.
   package Window_Trees is new Ada.Containers.Ordered_Maps
     (Key_Type     => Window_Key,
      Element_Type => A11ykit.Tree.Accessibility_Tree,
      "="          => A11ykit.Tree."=");

   Trees       : Window_Trees.Map;

   --  The frame nodes each window's tree was built from. A pointer move
   --  rebuilds the frame but mostly leaves these as they were: compared
   --  first, in one pass, they spare the containment search that gives the
   --  tree its parents (A11ykit.Tree.Build, quadratic in the nodes).
   package Window_Inputs is new Ada.Containers.Ordered_Maps
     (Key_Type     => Window_Key,
      Element_Type => Guikit.Draw.Accessibility_Node_Vectors.Vector,
      "="          => Guikit.Draw.Accessibility_Node_Vectors."=");

   Inputs      : Window_Inputs.Map;

   --  While no assistive technology listens (A11ykit.Provider.Listening), a
   --  changed frame's nodes wait here, and are published at most once per
   --  Files.Application.Window_Policy.Quiet_Publish_Interval: the provider
   --  keeps a tree to be found by, a little behind. Once one listens, what
   --  waits is published on the next pass (Service) and every change after
   --  that at once.
   --  Each window keeps its own interval: one window whose nodes change
   --  every frame (paste progress) must not keep another's tree waiting.
   Waiting      : Window_Inputs.Map;
   package Publish_Times is new Ada.Containers.Ordered_Maps
     (Key_Type => Window_Key, Element_Type => Ada.Real_Time.Time, "=" => Ada.Real_Time."=");
   Last_Publish : Publish_Times.Map;
   Focused     : Window_Key := 0;
   Last_Key    : Window_Key := 0;

   --  Where each window's nodes start in the combined tree (one before its
   --  first node), in the order they were combined.
   type Window_Range is record
      Window : Window_Key := 0;
      Offset : Natural := 0;
      Count  : Natural := 0;
   end record;

   package Range_Vectors is new Ada.Containers.Vectors (Positive, Window_Range);
   Ranges : Range_Vectors.Vector;

   --  Each window's native handle, by its key.
   package Native_Handles is new Ada.Containers.Ordered_Maps
     (Key_Type => Window_Key, Element_Type => System.Address, "=" => System."=");
   Handles : Native_Handles.Map;

   --  Between the session's Stop and a new Start: a window that still
   --  closes or draws does not register the application again.
   Stopped : Boolean := False;

   procedure Start is
   begin
      Stopped := False;
      A11ykit.Provider.Start;
   end Start;

   procedure Stop is
   begin
      Stopped := True;
      Trees.Clear;
      Inputs.Clear;
      Waiting.Clear;
      Last_Publish.Clear;
      Ranges.Clear;
      Handles.Clear;
      Focused := 0;
      A11ykit.Provider.Stop;
   end Stop;

   --  Name each window to the provider by its place among the combined
   --  tree's windows, which shifts as windows come and go.
   procedure Attach_Windows is
      Top_Level : Positive := 1;
   begin
      for Item of Ranges loop
         if Handles.Contains (Item.Window) then
            A11ykit.Provider.Attach_Window (Handles.Element (Item.Window), Top_Level);
         end if;
         Top_Level := Top_Level + 1;
      end loop;
   end Attach_Windows;

   procedure Attach_Window (Window : Window_Key; Native : System.Address) is
   begin
      Handles.Include (Window, Native);
      Attach_Windows;
   end Attach_Window;

   function New_Window_Key return Window_Key is
   begin
      Last_Key := Last_Key + 1;
      return Last_Key;
   end New_Window_Key;

   function Combined return A11ykit.Tree.Accessibility_Tree is
      Result : A11ykit.Tree.Accessibility_Tree;
   begin
      Ranges.Clear;
      for Position in Trees.Iterate loop
         declare
            Window : constant Window_Key := Window_Trees.Key (Position);
            Tree   : constant A11ykit.Tree.Accessibility_Tree := Window_Trees.Element (Position);
            Offset : constant Natural := Natural (Result.Nodes.Length);
            Root   : Boolean := True;
         begin
            Ranges.Append (Window_Range'(Window => Window, Offset => Offset, Count => Natural (Tree.Nodes.Length)));
            for Item of Tree.Nodes loop
               declare
                  Copy : A11ykit.Tree.Node := Item;
               begin
                  Copy.Parent := (if Item.Parent = 0 then 0 else Item.Parent + Offset);
                  --  The focused window's root is the active one.
                  if Item.Parent = 0 and then Root then
                     Copy.Node_State.Active := Window = Focused;
                     Root := False;
                  end if;
                  Result.Nodes.Append (Copy);
               end;
            end loop;
            if Window = Focused and then Tree.Focused /= 0 then
               Result.Focused := Tree.Focused + Offset;
            end if;
         end;
      end loop;
      return Result;
   end Combined;

   procedure Publish_Nodes
     (Window : Window_Key;
      Nodes  : Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      use type A11ykit.Tree.Accessibility_Tree;
      use type Guikit.Draw.Accessibility_Node_Vectors.Vector;
      First : constant Boolean := not Trees.Contains (Window);
   begin
      --  The same frame nodes make the same tree: nothing is built.
      if Stopped
        or else (not First and then Inputs.Contains (Window)
                 and then Inputs.Constant_Reference (Window) = Nodes)
      then
         Waiting.Exclude (Window);
         return;
      end if;
      if not Files.Application.Window_Policy.Publish_Due
          (First        => First,
           Listening    => A11ykit.Provider.Listening,
           Quiet_Passed =>
             Files.Timing.Elapsed
               (Ada.Real_Time.Clock,
                (if Last_Publish.Contains (Window) then Last_Publish.Element (Window)
                 else Ada.Real_Time.Time_First),
                Ada.Real_Time.To_Time_Span (Files.Application.Window_Policy.Quiet_Publish_Interval)))
      then
         Waiting.Include (Window, Nodes);
         return;
      end if;
      Waiting.Exclude (Window);
      Last_Publish.Include (Window, Ada.Real_Time.Clock);
      Inputs.Include (Window, Nodes);
      declare
         Tree : constant A11ykit.Tree.Accessibility_Tree := Tree_Of_Nodes (Nodes);
      begin
         --  An overlay is republished every frame it is up; an unchanged tree
         --  costs no combining, no provider diff and no native attach (and is
         --  compared in place, not copied out first).
         if not First and then Trees.Constant_Reference (Window) = Tree then
            return;
         end if;
         Trees.Include (Window, Tree);
      end;
      --  Native providers establish their host registration from the first
      --  tree, because only then is the application root known.  Available is
      --  therefore an outcome of Publish, not a precondition for calling it.
      A11ykit.Provider.Publish (Combined);
      --  The windows' order, which their attachment follows, changes only
      --  when one comes or goes (Attach_Window and Forget attach too).
      if First then
         Attach_Windows;
      end if;
   end Publish_Nodes;

   procedure Publish (Window : Window_Key; Frame : Files.Rendering.Frame_Commands) is
   begin
      Publish_Nodes (Window, Frame.Accessibility);
   end Publish;

   procedure Service is
   begin
      A11ykit.Provider.Service;
      --  What waited for the quiet interval, or for an assistive technology
      --  that has just started listening, is published now, without waiting
      --  for the window to draw again.
      if not Waiting.Is_Empty then
         declare
            Due : constant Window_Inputs.Map := Waiting;
         begin
            for Position in Due.Iterate loop
               Publish_Nodes (Window_Inputs.Key (Position), Window_Inputs.Element (Position));
            end loop;
         end;
      end if;
   end Service;

   function Published_Windows return Natural is (Natural (Trees.Length));

   function Waiting_Windows return Natural is (Natural (Waiting.Length));

   procedure Forget (Window : Window_Key) is
   begin
      Handles.Exclude (Window);
      Last_Publish.Exclude (Window);
      if Trees.Contains (Window) then
         Trees.Delete (Window);
         Inputs.Exclude (Window);
         Waiting.Exclude (Window);
         if Focused = Window then
            Focused := 0;
         end if;
         if not Trees.Is_Empty then
            A11ykit.Provider.Publish (Combined);
            Attach_Windows;
         else
            --  The last window closed: unregister now, so the screen reader is
            --  not left reading it until the session's own Stop (Stop is
            --  idempotent; a new window's first Publish registers again).
            A11ykit.Provider.Stop;
         end if;
      end if;
   end Forget;

   procedure Set_Active (Window : Window_Key) is
   begin
      if not Stopped and then Window /= Focused then
         if Focused /= 0 then
            A11ykit.Provider.Set_Active (False);
         end if;
         Focused := Window;
         if not Trees.Is_Empty then
            A11ykit.Provider.Publish (Combined);
         end if;
         if Window /= 0 then
            A11ykit.Provider.Set_Active (True);
         end if;
      end if;
   end Set_Active;

   function Next_Request
     (Window : out Window_Key;
      Item   : out A11ykit.Provider.Request)
      return Boolean is
   begin
      Window := 0;
      while A11ykit.Provider.Next_Request (Item) loop
         Files.Diagnostics.Trace
           ("Files.Application.Accessibility",
            --  A developer trace: field=value pairs, no prose.
            "kind=" & A11ykit.Provider.Request_Kind'Image (Item.Kind) & ',' & "node=" & Item.Node'Image
            & ',' & "windows=" & Ranges.Length'Image);
         for Part of Ranges loop
            if Item.Node > Part.Offset and then Item.Node <= Part.Offset + Part.Count then
               Window := Part.Window;
               Item.Node := Item.Node - Part.Offset;
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end Next_Request;

end Files.Application.Accessibility;
