using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Text;
using System.Windows.Forms;
using System.Drawing.Design;
using Newtonsoft.Json;
using System.IO;
using System.Threading;
using EPocalipse.Json.Viewer.Properties;
using SemiTwist.Util;

namespace EPocalipse.Json.Viewer
{
    public partial class JsonViewer : UserControl
    {
        private string _json;
        private int _maxErrorCount = 25;
        private ErrorDetails _errorDetails;
        private PluginsManager _pluginsManager = new PluginsManager();
        bool _updating;
        Control _lastVisualizerControl;
        private bool skipSrcSelectionChangedEvent=false;

        private JsonObjectTree tree;

        private Color tvJsonOriginalBackColor;
        private Color tvJsonOriginalForeColor;

        private Color tvJsonHighlightBackColor;
        private Color tvJsonHighlightForeColor;

        private Color rtxtParsedSrcOriginalBackColor;
        private Color rtxtParsedSrcOriginalForeColor;
        private Font  rtxtParsedSrcOriginalFont;

        private Color rtxtParsedSrcHighlightBackColor;
        private Color rtxtParsedSrcHighlightForeColor;
        private Font  rtxtParsedSrcHighlightFont;

        private Color rtxtParsedSrcErrorBackColor;
        private Color rtxtParsedSrcErrorForeColor;
        private Font  rtxtParsedSrcErrorFont;

        private int lblParseSrcFileLocY;

        private string parsedSrc;
        private JsonViewerTreeNode highlightedNode;

        public JsonViewer()
        {
            InitializeComponent();
            try
            {
                _pluginsManager.Initialize();
            }
            catch (Exception e)
            {
                MessageBox.Show(String.Format(Resources.ConfigMessage, e.Message), "Json Viewer", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }

            tvJsonHighlightBackColor = Color.Blue;
            tvJsonHighlightForeColor = Color.White;

            tvJsonOriginalBackColor = tvJson.BackColor;
            tvJsonOriginalForeColor = tvJson.ForeColor;

            rtxtParsedSrcOriginalBackColor = rtxtParsedSrc.BackColor;
            rtxtParsedSrcOriginalForeColor = rtxtParsedSrc.ForeColor;
            rtxtParsedSrcOriginalFont      = rtxtParsedSrc.Font;

            rtxtParsedSrcHighlightBackColor = Color.Blue;
            rtxtParsedSrcHighlightForeColor = Color.White;
            //rtxtParsedSrcHighlightFont      = new Font(rtxtParsedSrcOriginalFont, FontStyle.Bold);
            rtxtParsedSrcHighlightFont      = rtxtParsedSrcOriginalFont;

            rtxtParsedSrcErrorBackColor = rtxtParsedSrcOriginalBackColor;
            rtxtParsedSrcErrorForeColor = Color.Red;
            rtxtParsedSrcErrorFont      = new Font(rtxtParsedSrcOriginalFont, FontStyle.Bold);

            lblParseSrcFileLocY = lblParseSrcFile.Location.Y;

            UpdatePanelSplitterPositions();
            UpdateParseSourceView();
        }

        [Editor("System.ComponentModel.Design.MultilineStringEditor, System.Design, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a", typeof(UITypeEditor))]
        public string Json
        {
            get
            {
                return _json;
            }
            set
            {
                if (_json != value)
                {
                    _json = value.Trim();
                    txtJson.Text = _json;

                    tree = null;
                    if(!String.IsNullOrEmpty(_json))
                        tree = JsonObjectTree.Parse(_json);

                    ParseTreeMode =
                        (GetRootishValue("parseTreeMode").Trim().ToLower() == "true");
                    Redraw();
                }
            }
        }

        public bool ParseTreeMode
        {
            get
            {
                return ckParseTreeMode.Checked;
            }
            set
            {
                bool valueChanging = (ckParseTreeMode.Checked != value);
                if(valueChanging)
                    ckParseTreeMode.Checked = value;
                else
                    UpdateParseTreeMode();
            }
        }

        [DefaultValue(25)]
        public int MaxErrorCount
        {
            get
            {
                return _maxErrorCount;
            }
            set
            {
                _maxErrorCount = value;
            }
        }

        private void Redraw()
        {
            try
            {
                tvJson.BeginUpdate();
                try
                {
                    Reset();
                    VisualizeJsonTree();
                }
                finally
                {
                    tvJson.EndUpdate();
                }
            }
            catch (JsonParseError e)
            {
                GetParseErrorDetails(e);
            }
            catch (Exception e)
            {
                ShowException(e);
            }
        }

        private void Reset()
        {
            ClearInfo();
            tvJson.Nodes.Clear();
            pnlVisualizer.Controls.Clear();
            _lastVisualizerControl = null;
            cbVisualizers.Items.Clear();
        }

        private void GetParseErrorDetails(Exception parserError)
        {
            UnbufferedStringReader strReader = new UnbufferedStringReader(_json);
            using (JsonReader reader = new JsonReader(strReader))
            {
                try
                {
                    while (reader.Read()) { };
                }
                catch (Exception e)
                {
                    _errorDetails._err = e.Message;
                    _errorDetails._pos = strReader.Position;
                }
            }
            if (_errorDetails.Error == null)
                _errorDetails._err = parserError.Message;
            if (_errorDetails.Position == 0)
                _errorDetails._pos = _json.Length;
            if (!txtJson.ContainsFocus)
                MarkError(_errorDetails);
            ShowInfo(_errorDetails);
        }

        private void MarkError(ErrorDetails _errorDetails)
        {
            txtJson.Select(Math.Max(0, _errorDetails.Position - 1), 10);
            txtJson.ScrollToCaret();
        }

        private void VisualizeJsonTree()
        {
            if(tree != null)
            {
                AddNode(tvJson.Nodes, tree.Root);
                JsonViewerTreeNode node = GetRootNode();
                InitVisualizers(node);
                node.Expand();
                tvJson.SelectedNode = node;
            }
        }

        private string GetNodeLabel(JsonObject jsonObject)
        {
            string label = jsonObject.Text;

            if(txtLabelName.Text.Trim() != "")
            {
                JsonObject extraField = jsonObject.Fields[txtLabelName.Text.Trim()];
                string extra = 
                        (extraField != null && extraField.JsonType == JsonType.Value)?
                        ": "+extraField.Value : "";

                label += extra;
            }
            else if(ParseTreeMode)
            {
                try
                {
                    int srcIndexStart = Convert.ToInt32(GetValue(jsonObject, "srcIndexStart"));
                    int srcLength     = Convert.ToInt32(GetValue(jsonObject, "srcLength"));
                    bool shortened=false;
                    if(srcLength > 256)
                    {
                        srcLength = 256;
                        shortened = true;
                    }

                    Util.ClampRange(ref srcIndexStart, ref srcLength, 0, parsedSrc.Length);
                    string labelExtra = parsedSrc.Substring(srcIndexStart, srcLength).Trim();
                    int indexOfNewline = labelExtra.IndexOfAny(new char[]{'\n', '\r'});
                    if(indexOfNewline != -1)
                    {
                        labelExtra = labelExtra.Substring(0, indexOfNewline);
                        shortened = true;
                    }

                    label += ": " + labelExtra;
                    if(shortened && labelExtra.Trim() != "")
                        label += "...";
                }
                catch(ArgumentOutOfRangeException) { }
                catch(FormatException)
                {
                    // It's ok, srcIndexStart and srcLength either didn't exist
                    // or were invalid, so just don't add anything.
                }
            }

            return label;
        }

        private void AddNode(TreeNodeCollection nodes, JsonObject jsonObject)
        {
            if(!ckObjectsOnly.Checked || jsonObject.JsonType == JsonType.Object)
            {
                JsonViewerTreeNode newNode = new JsonViewerTreeNode(jsonObject);
                nodes.Add(newNode);

                newNode.Text = GetNodeLabel(jsonObject);
                newNode.Tag = jsonObject;
                newNode.ImageIndex = (int)jsonObject.JsonType;
                newNode.SelectedImageIndex = newNode.ImageIndex;

                foreach(JsonObject field in jsonObject.Fields)
                {
                    AddNode(newNode.Nodes, field);
                }
            }
        }

        public ErrorDetails ErrorDetails
        {
            get
            {
                return _errorDetails;
            }
        }

        public void Clear()
        {
            Json = String.Empty;
        }

        public void ShowInfo(string info)
        {
            lblError.Text = info;
            lblError.Tag = null;
            lblError.Enabled = false;
            tabControl.SelectedTab = pageTextView;
        }

        public void ShowInfo(ErrorDetails error)
        {
            ShowInfo(error.Error);
            lblError.Text = error.Error;
            lblError.Tag = error;
            lblError.Enabled = true;
            tabControl.SelectedTab = pageTextView;
        }

        public void ClearInfo()
        {
            lblError.Text = String.Empty;
        }

        public bool HasErrors
        {
            get
            {
                return _errorDetails._err != null;
            }
        }

        private void txtJson_TextChanged(object sender, EventArgs e)
        {
            Json = txtJson.Text;
        }

        private void txtFind_TextChanged(object sender, EventArgs e)
        {
            txtFind.BackColor = SystemColors.Window;
            FindNext(true, true);
        }

        public bool FindNext(bool includeSelected)
        {
            return FindNext(txtFind.Text, includeSelected);
        }

        public void FindNext(bool includeSelected, bool fromUI)
        {
            if (!FindNext(includeSelected) && fromUI)
                txtFind.BackColor = Color.LightCoral;
        }

        public bool FindNext(string text, bool includeSelected)
        {
            TreeNode startNode = tvJson.SelectedNode;
            if (startNode == null && HasNodes())
                startNode = GetRootNode();
            if (startNode != null)
            {
                startNode = FindNext(startNode, text, includeSelected);
                if (startNode != null)
                {
                    tvJson.SelectedNode = startNode;
                    return true;
                }
            }
            return false;
        }

        public TreeNode FindNext(TreeNode startNode, string text, bool includeSelected)
        {
            if (text == String.Empty)
                return startNode;

            if (includeSelected && IsMatchingNode(startNode, text))
                return startNode;

            TreeNode originalStartNode = startNode;
            startNode = GetNextNode(startNode);
            text = text.ToLower();
            while (startNode != originalStartNode)
            {
                if (IsMatchingNode(startNode, text))
                    return startNode;
                startNode = GetNextNode(startNode);
            }

            return null;
        }

        private TreeNode GetNextNode(TreeNode startNode)
        {
            TreeNode next = startNode.FirstNode ?? startNode.NextNode;
            if (next == null)
            {
                while (startNode != null && next == null)
                {
                    startNode = startNode.Parent;
                    if (startNode != null)
                        next = startNode.NextNode;
                }
                if (next == null)
                {
                    next = GetRootNode();
                    FlashControl(txtFind, Color.Cyan);
                }
            }
            return next;
        }

        private bool IsMatchingNode(TreeNode startNode, string text)
        {
            return (startNode.Text.ToLower().Contains(text));
        }

        private JsonViewerTreeNode GetRootNode()
        {
            if (tvJson.Nodes.Count > 0)
                return (JsonViewerTreeNode)tvJson.Nodes[0];
            return null;
        }

        private bool HasNodes()
        {
            return (tvJson.Nodes.Count > 0);
        }

        private void txtFind_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter)
            {
                FindNext(false, true);
            }
            if (e.KeyCode == Keys.Escape)
            {
                HideFind();
            }
        }

        private void FlashControl(Control control, Color color)
        {
            Color prevColor = control.BackColor;
            try
            {
                control.BackColor = color;
                control.Refresh();
                Thread.Sleep(25);
            }
            finally
            {
                control.BackColor = prevColor;
                control.Refresh();
            }
        }

        public void ShowTab(Tabs tab)
        {
            tabControl.SelectedIndex = (int)tab;
        }

        private void btnFormat_Click(object sender, EventArgs e)
        {
            try
            {
                string json = txtJson.Text;
                JsonSerializer s = new JsonSerializer();
                JsonReader reader = new JsonReader(new StringReader(json));
                Object jsonObject = s.Deserialize(reader);
                if (jsonObject != null)
                {
                    StringWriter sWriter = new StringWriter();
                    JsonWriter writer = new JsonWriter(sWriter);
                    writer.Formatting = Formatting.Indented;
                    writer.Indentation = 4;
                    writer.IndentChar = ' ';
                    s.Serialize(writer, jsonObject);
                    txtJson.Text = sWriter.ToString();
                }
            }
            catch (Exception ex)
            {
                ShowException(ex);
            }
        }

        private void ShowException(Exception e)
        {
            MessageBox.Show(this, e.Message, "Json Viewer", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        private void btnStripToSqr_Click(object sender, EventArgs e)
        {
            StripTextTo('[', ']');
        }

        private void btnStripToCurly_Click(object sender, EventArgs e)
        {
            StripTextTo('{', '}');
        }

        private void StripTextTo(char sChr, char eChr)
        {
            string text = txtJson.Text;
            int start = text.IndexOf(sChr);
            int end = text.LastIndexOf(eChr);
            int newLen = end - start + 1;
            if (newLen > 1)
            {
                txtJson.Text = text.Substring(start, newLen);
            }
        }

        private void tvJson_AfterSelect(object sender, TreeViewEventArgs e)
        {
            if (_pluginsManager.DefaultVisualizer == null)
                return;

            JsonViewerTreeNode node = (JsonViewerTreeNode)e.Node;
            cbVisualizers.BeginUpdate();
            _updating = true;
            try
            {
                IJsonVisualizer lastActive = node.LastVisualizer;
                if (lastActive == null)
                    lastActive = (IJsonVisualizer)cbVisualizers.SelectedItem;
                if (lastActive == null)
                    lastActive = _pluginsManager.DefaultVisualizer;

                cbVisualizers.Items.Clear();
                cbVisualizers.Items.AddRange(node.Visualizers.ToArray());
                int index = cbVisualizers.Items.IndexOf(lastActive);
                if (index != -1)
                {
                    cbVisualizers.SelectedIndex = index;
                }
                else
                {
                    cbVisualizers.SelectedIndex = cbVisualizers.Items.IndexOf(_pluginsManager.DefaultVisualizer);
                }
            }
            finally
            {
                cbVisualizers.EndUpdate();
                _updating = false;
            }
            ActivateVisualizer();

            SelectNodeInSource(node.JsonObject);
            DehighlightNode(highlightedNode);
        }

        private void SelectNodeInSource(JsonObject obj)
        {
            if(obj != null && ParseTreeMode)
            {
                DehighlightParsedSrc();
                try
                {
                    int srcIndexStart = Convert.ToInt32(GetValue(obj, "srcIndexStart"));
                    int srcLength     = Convert.ToInt32(GetValue(obj, "srcLength"));
                    Util.ClampRange(ref srcIndexStart, ref srcLength, 0, parsedSrc.Length);
                    HighlightParsedSrc(srcIndexStart, srcLength);
                }
                catch(FormatException)
                {
                    // It's ok, srcIndexStart and srcLength either didn't exist
                    // or were invalid, so just don't highlight anything.
                }
            }
        }

        private void ActivateVisualizer()
        {
            IJsonVisualizer visualizer = (IJsonVisualizer)cbVisualizers.SelectedItem;
            if (visualizer != null)
            {
                JsonObject jsonObject = GetSelectedTreeNode().JsonObject;
                Control visualizerCtrl = visualizer.GetControl(jsonObject);
                if (_lastVisualizerControl != visualizerCtrl)
                {
                    pnlVisualizer.Controls.Remove(_lastVisualizerControl);
                    pnlVisualizer.Controls.Add(visualizerCtrl);
                    visualizerCtrl.Dock = DockStyle.Fill;
                    _lastVisualizerControl = visualizerCtrl;
                }
                visualizer.Visualize(jsonObject);
            }
        }


        private void cbVisualizers_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (!_updating && GetSelectedTreeNode() != null)
            {
                ActivateVisualizer();
                GetSelectedTreeNode().LastVisualizer = (IJsonVisualizer)cbVisualizers.SelectedItem;
            }
        }

        private JsonViewerTreeNode GetSelectedTreeNode()
        {
            return (JsonViewerTreeNode)tvJson.SelectedNode;
        }

        private void tvJson_BeforeExpand(object sender, TreeViewCancelEventArgs e)
        {
            foreach (JsonViewerTreeNode node in e.Node.Nodes)
            {
                InitVisualizers(node);
            }
        }

        private void InitVisualizers(JsonViewerTreeNode node)
        {
            if (!node.Initialized)
            {
                node.Initialized = true;
                JsonObject jsonObject = node.JsonObject;
                foreach (ICustomTextProvider textVis in _pluginsManager.TextVisualizers)
                {
                    if (textVis.CanVisualize(jsonObject))
                        node.TextVisualizers.Add(textVis);
                }

                node.RefreshText();

                foreach (IJsonVisualizer visualizer in _pluginsManager.Visualizers)
                {
                    if (visualizer.CanVisualize(jsonObject))
                        node.Visualizers.Add(visualizer);
                }
            }
        }

        private void btnCloseFind_Click(object sender, EventArgs e)
        {
            HideFind();
        }

        private void JsonViewer_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.F && e.Control)
            {
                ShowFind();
            }
        }

        private void HideFind()
        {
            pnlFind.Visible = false;
            tvJson.Focus();
        }

        private void ShowFind()
        {
            pnlFind.Visible = true;
            txtFind.Focus();
        }

        private void findToolStripMenuItem_Click(object sender, EventArgs e)
        {
            ShowFind();
        }

        private void expandallToolStripMenuItem_Click(object sender, EventArgs e)
        {
            tvJson.BeginUpdate();
            try
            {
                if (tvJson.SelectedNode != null)
                {
                    TreeNode topNode = tvJson.TopNode;
                    tvJson.SelectedNode.ExpandAll();
                    tvJson.TopNode = topNode;
                }
            }
            finally
            {
                tvJson.EndUpdate();
            }
        }

        private void tvJson_MouseDown(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Right)
            {
                TreeNode node = tvJson.GetNodeAt(e.Location);
                if (node != null)
                {
                    tvJson.SelectedNode = node;
                }
            }
        }

        private void rightToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (sender == mnuShowOnBottom)
            {
                spcViewer.Orientation = Orientation.Horizontal;
                mnuShowOnRight.Checked = false;
            }
            else
            {
                spcViewer.Orientation = Orientation.Vertical;
                mnuShowOnBottom.Checked = false;
            }
        }

        private void cbVisualizers_Format(object sender, ListControlConvertEventArgs e)
        {
            e.Value = ((IJsonViewerPlugin)e.ListItem).DisplayName;
        }

        private void mnuTree_Opening(object sender, CancelEventArgs e)
        {
            mnuFind.Enabled = (GetRootNode() != null);
            mnuExpandAll.Enabled = (GetSelectedTreeNode() != null);

            mnuCopy.Enabled = mnuExpandAll.Enabled;
            mnuCopyValue.Enabled = mnuExpandAll.Enabled;
        }

        private void btnCopy_Click(object sender, EventArgs e)
        {
            string text;
            if (txtJson.SelectionLength > 0)
                text = txtJson.SelectedText;
            else
                text = txtJson.Text;
            Clipboard.SetText(text);
        }

        private void btnPaste_Click(object sender, EventArgs e)
        {
            txtJson.Text = Clipboard.GetText();
        }

        private void mnuCopy_Click(object sender, EventArgs e)
        {
            JsonViewerTreeNode node = GetSelectedTreeNode();
            if (node != null)
            {
                Clipboard.SetText(node.Text);
            }
        }

        private void mnuCopyValue_Click(object sender, EventArgs e)
        {
            JsonViewerTreeNode node = GetSelectedTreeNode();
            if (node != null && node.JsonObject.Value != null)
            {
                Clipboard.SetText(node.JsonObject.Value.ToString());
            }
        }

        private void lblError_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
        {
            if (lblError.Enabled && lblError.Tag != null)
            {
                ErrorDetails err = (ErrorDetails)lblError.Tag;
                MarkError(err);
            }
        }

        private void removeNewLineMenuItem_Click(object sender, EventArgs e)
        {
            StripFromText('\n', '\r');
        }

        private void removeSpecialCharsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            string text = txtJson.Text;
            text = text.Replace(@"\""", @"""");
            txtJson.Text = text;
        }

        private void StripFromText(params char[] chars)
        {
            string text = txtJson.Text;
            foreach (char ch in chars)
            {
                text = text.Replace(ch.ToString(), "");
            }
            txtJson.Text = text;
        }

        private void ckObjectsOnly_CheckedChanged(object sender, EventArgs e)
        {
            Redraw();
        }

        private void txtLabelName_TextChanged(object sender, EventArgs e)
        {
            Redraw();
        }

        private string GetValue(JsonObject obj, string key)
        {
            return obj.ContainsField(key, JsonType.Value)?
                ""+obj.Fields[key].Value : "";
        }

        private string GetRootishValue(string key)
        {
            string value="";
            if(tree != null && tree.Root != null)
            {
                value = GetValue(tree.Root, key);
                if(value == "")
                {
                    foreach(JsonObject obj in tree.Root.Fields)
                    {
                        value = GetValue(obj, key);
                        if(value != "")
                            break;
                    }
                }
            }
            return value;
        }

        private void ChangeParsedSrcStyleToOriginal()
        {
            rtxtParsedSrc.BackColor = rtxtParsedSrcOriginalBackColor;
            rtxtParsedSrc.ForeColor = rtxtParsedSrcOriginalForeColor;
            rtxtParsedSrc.Font      = rtxtParsedSrcOriginalFont;
        }

        private void ChangeParsedSrcStyleToError()
        {
            rtxtParsedSrc.BackColor = rtxtParsedSrcErrorBackColor;
            rtxtParsedSrc.ForeColor = rtxtParsedSrcErrorForeColor;
            rtxtParsedSrc.Font      = rtxtParsedSrcErrorFont;
        }

        private void UpdateParseSourceContent()
        {
            if(ParseTreeMode)
            {
                parsedSrc = GetRootishValue("source");
                if(parsedSrc != "")
                {
                    lblParseSrcFile.Text = "{Embedded Source}:";
                    ChangeParsedSrcStyleToOriginal();
                    rtxtParsedSrc.Text = parsedSrc;
                    lblParseSrcFile.Location = new Point(lblParseSrcFile.Location.X, lblParseSrcFileLocY);
                }
                else
                {
                    string filename = GetRootishValue("file").Trim();
                    if(filename != "")
                    {
                        lblParseSrcFile.Text = filename+":\n{WARNING: Could be out-of-date if changed after json tree was generated}";
                        lblParseSrcFile.Location = new Point(lblParseSrcFile.Location.X, 0);
                        try
                        {
                            ChangeParsedSrcStyleToOriginal();

                            // The RichTextBox will strip the '\r's
                            // (although it won't do it immediately)
                            parsedSrc = File.ReadAllText(filename);
                            rtxtParsedSrc.Text = parsedSrc;
                        }
                        catch(FileNotFoundException)
                        {
                            ChangeParsedSrcStyleToError();
                            rtxtParsedSrc.Text = "{File Not Found}";
                        }
                        catch(IOException)
                        {
                            ChangeParsedSrcStyleToError();
                            rtxtParsedSrc.Text = "{Error Reading File}";
                        }
                    }
                    else
                        lblParseSrcFile.Text = "{No Referenced File}";
                }
            }
        }

        private void UpdateParseTreeMode()
        {
            skipSrcSelectionChangedEvent = true;

            UpdateParseSourceContent();
            UpdatePanelSplitterPositions();
            UpdateParseSourceView();

            ckObjectsOnly.Checked = ParseTreeMode;

            skipSrcSelectionChangedEvent = false;
        }

        private void ckParseTreeMode_CheckedChanged(object sender, EventArgs e)
        {
            UpdateParseTreeMode();
        }

        private void UpdatePanelSplitterPositions()
        {
            spcViewer.SplitterDistance =
                (int)Util.DeNormalize(
                    ParseTreeMode? .85 : .75,
                    0, spcViewer.Size.Width
                );

            spcViewer2.SplitterDistance =
                (int)Util.DeNormalize(
                    ParseTreeMode? .35 : .95,
                    0, spcViewer2.Size.Width
                );
        }

        private void UpdateParseSourceView()
        {
            spcViewer2.Panel2Collapsed = !ParseTreeMode;
        }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {
            UpdateParseSourceView();
        }

        private void NewlineAdjustedSelect(RichTextBox box, int start, int length)
        {
            int numCrNlBeforeStart = Util.CountCrNl(parsedSrc, 0, start);
            int numCrNlInSelection = Util.CountCrNl(parsedSrc, start, length);
            start -= numCrNlBeforeStart;
            length -= numCrNlInSelection;
            Util.ClampRange(ref start, ref length, 0, box.Text.Length);
            box.Select(start, length);
        }

        private void HighlightParsedSrc(int start, int length)
        {
            //skipSrcSelectionChangedEvent = true;
            //int saveSelectionStart  = rtxtParsedSrc.SelectionStart;
            //int saveSelectionLength = rtxtParsedSrc.SelectionLength;

            NewlineAdjustedSelect(rtxtParsedSrc, start, length);
            rtxtParsedSrc.SelectionFont      = rtxtParsedSrcHighlightFont;
            rtxtParsedSrc.SelectionColor     = rtxtParsedSrcHighlightForeColor;
            rtxtParsedSrc.SelectionBackColor = rtxtParsedSrcHighlightBackColor;
            rtxtParsedSrc.DeselectAll();

            //rtxtParsedSrc.SelectionStart  = saveSelectionStart;
            //rtxtParsedSrc.SelectionLength = saveSelectionLength;
            //skipSrcSelectionChangedEvent = false;
        }

        private void DehighlightParsedSrc()
        {
            //skipSrcSelectionChangedEvent = true;
            //int saveSelectionStart  = rtxtParsedSrc.SelectionStart;
            //int saveSelectionLength = rtxtParsedSrc.SelectionLength;

            rtxtParsedSrc.SelectAll();
            rtxtParsedSrc.SelectionFont      = rtxtParsedSrcOriginalFont;
            rtxtParsedSrc.SelectionColor     = rtxtParsedSrcOriginalForeColor;
            rtxtParsedSrc.SelectionBackColor = rtxtParsedSrcOriginalBackColor;
            rtxtParsedSrc.DeselectAll();

            //rtxtParsedSrc.SelectionStart  = saveSelectionStart;
            //rtxtParsedSrc.SelectionLength = saveSelectionLength;
            //skipSrcSelectionChangedEvent = false;
        }

        private void HighlightNode(TreeNode node)
        {
            if(node != null)
            {
                node.BackColor = tvJsonHighlightBackColor;
                node.ForeColor = tvJsonHighlightForeColor;
            }
        }

        private void DehighlightNode(TreeNode node)
        {
            if(node != null)
            {
                node.BackColor = tvJsonOriginalBackColor;
                node.ForeColor = tvJsonOriginalForeColor;
            }
        }

        private void rtxtParsedSrc_SelectionChanged(Object sender, EventArgs e)
        {
        }

        private void rtxtParsedSrc_GotFocus(Object sender, EventArgs e)
        {
            btnJumpToNode.Enabled = true;
        }

        private void rtxtParsedSrc_LostFocus(Object sender, EventArgs e)
        {
            btnJumpToNode.Enabled = false;
        }

        private void btnJumpToNode_Click(object sender, EventArgs e)
        {
            if(!skipSrcSelectionChangedEvent)
            {
                int selectionStart = rtxtParsedSrc.SelectionStart;
                selectionStart += Util.CountMissingCrNl(parsedSrc, rtxtParsedSrc.Text, selectionStart);

                JsonViewerTreeNode node = GetRootNode();
                bool done = false;
                while(!done)
                {
                    JsonViewerTreeNode prevSubNode = null;
                    JsonViewerTreeNode nextNode = null;
                    foreach(TreeNode subNodeBase in node.Nodes)
                    {
                        JsonViewerTreeNode subNode = (JsonViewerTreeNode)subNodeBase;
                        JsonObject jsonObj = subNode.JsonObject;

                        int srcIndexStart = Convert.ToInt32(GetValue(jsonObj, "srcIndexStart"));
                        if(srcIndexStart > selectionStart)
                        {
                            nextNode = prevSubNode;
                            break;
                        }

                        prevSubNode = subNode;
                    }

                    if(nextNode == null)
                    {
                        if(prevSubNode == null)
                            done = true;
                        else
                            node = prevSubNode;
                    }
                    else
                        node = nextNode;
                }

                DehighlightNode(highlightedNode);

                // Go to the node, but then de-select it so the highlight will show
                tvJson.SelectedNode = node;
                tvJson.SelectedNode = null;

                HighlightNode(node);
                highlightedNode = node;

                //TODO: Scroll treeview left/right to make sure node is on-screen (possible?)
                //node.Bounds.Left
                //tvJson.ScrollControlIntoView(node);
                //scrollTarget.Bounds = node.Bounds;
                //scrollTarget.AutoScrollOffset = new Point(scrollTarget.Width, 0);
                //spcViewer2.Panel1.ScrollControlIntoView(scrollTarget);
            }
        }
    }

    public struct ErrorDetails
    {
        internal string _err;
        internal int _pos;

        public string Error
        {
            get
            {
                return _err;
            }
        }

        public int Position
        {
            get
            {
                return _pos;
            }
        }

        public void Clear()
        {
            _err = null;
            _pos = 0;
        }
    }

    public class JsonViewerTreeNode : TreeNode
    {
        JsonObject _jsonObject;
        List<ICustomTextProvider> _textVisualizers = new List<ICustomTextProvider>();
        List<IJsonVisualizer> _visualizers = new List<IJsonVisualizer>();
        private bool _init;
        private IJsonVisualizer _lastVisualizer;

        public JsonViewerTreeNode(JsonObject jsonObject)
        {
            _jsonObject = jsonObject;
        }

        public List<ICustomTextProvider> TextVisualizers
        {
            get
            {
                return _textVisualizers;
            }
        }

        public List<IJsonVisualizer> Visualizers
        {
            get
            {
                return _visualizers;
            }
        }

        public JsonObject JsonObject
        {
            get
            {
                return _jsonObject;
            }
        }

        internal bool Initialized
        {
            get
            {
                return _init;
            }
            set
            {
                _init = value;
            }
        }

        internal void RefreshText()
        {
//            StringBuilder sb = new StringBuilder(_jsonObject.Text);
            StringBuilder sb = new StringBuilder(this.Text);
            foreach(ICustomTextProvider textVisualizer in _textVisualizers)
            {
                try
                {
                    string customText = textVisualizer.GetText(_jsonObject);
                    sb.Append(" (" + customText + ")");
                }
                catch
                {
                    //silently ignore
                }
            }
            string text = sb.ToString();
            if (text != this.Text)
                this.Text = text;
        }

        public IJsonVisualizer LastVisualizer
        {
            get
            {
                return _lastVisualizer;
            }
            set
            {
                _lastVisualizer = value;
            }
        }
    }

    public enum Tabs { Viewer, Text };
}