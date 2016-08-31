
//
//  MainWindowController.swift
//  minimalTunes
//
//  Created by John Moody on 5/30/16.
//  Copyright © 2016 John Moody. All rights reserved.
//

import Cocoa
import CoreData

private var my_context = 0


class MainWindowController: NSWindowController, NSOutlineViewDelegate, NSSearchFieldDelegate, NSTableViewDelegate {
    
    @IBOutlet weak var albumArtBox: NSBox!
    @IBOutlet weak var artworkToggle: NSButton!
    @IBOutlet weak var artCollectionView: NSCollectionView!
    @IBOutlet weak var noMusicView: NSView!
    @IBOutlet weak var queueScrollView: NSScrollView!
    @IBOutlet weak var queueButton: NSButton!
    @IBOutlet weak var volumeSlider: NSSlider!
    @IBOutlet weak var auxPlaylistTableView: TableViewYouCanPressSpacebarOn!
    @IBOutlet weak var auxPlaylistScrollView: NSScrollView!
    @IBOutlet weak var librarySplitView: NSSplitView!
    @IBOutlet weak var advancedFilterScrollView: NSScrollView!
    @IBOutlet weak var trackQueueTableView: TableViewYouCanPressSpacebarOn!
    @IBOutlet weak var progressBarView: dragAndDropView!
    @IBOutlet weak var shuffleButton: NSButton!
    @IBOutlet weak var trackListBox: NSBox!
    @IBOutlet weak var trackListTriangle: NSButton!
    @IBOutlet weak var headerCellView: NSTableCellView!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var songNameLabel: NSTextField!
    @IBOutlet weak var artistAlbumLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var theBox: NSBox!
    @IBOutlet weak var sourceListScrollView: NSScrollView!
    @IBOutlet weak var libraryTableScrollView: NSScrollView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet var sourceListTreeController: DragAndDropTreeController!
    @IBOutlet var tableViewArrayController: DragAndDropArrayController!
    @IBOutlet var auxPlaylistArrayController: DragAndDropArrayController!
    @IBOutlet weak var sourceListView: SourceListThatYouCanPressSpacebarOn!
    @IBOutlet weak var libraryTableView: TableViewYouCanPressSpacebarOn!
    @IBOutlet weak var albumArtView: DragAndDropImageView!
    @IBOutlet var artCollectionArrayController: NSArrayController!
    @IBOutlet weak var infoField: NSTextField!
    
    enum windowFocus {
        case playlist
        case library
    }
    
    var currentArrayController: DragAndDropArrayController?
    var currentTableView: TableViewYouCanPressSpacebarOn?
    
    var tagWindowController: TagEditorWindow?
    var importWindowController: ImportWindowController?
    var timer: NSTimer?
    var lastTimerDate: NSDate?
    var secsPlayed: NSTimeInterval = 0
    var queue: AudioQueue = AudioQueue()
    var cur_view_title = "Music"
    var cur_source_title = "Music"
    var duration: Double?
    var paused: Bool?
    var is_initialized = false
    let trackQueueTableDelegate = TrackQueueTableViewDelegate()
    var shuffle = NSOnState
    var currentTrack: Track?
    var current_source_play_order: [Int]?
    var current_source_temp_shuffle: [Int]?
    var current_source_index: Int?
    var current_source_index_temp: Int?
    var infoString: String?
    var auxArrayController: NSArrayController?
    var focus: windowFocus = windowFocus.library
    var hasMusic: Bool = false
    var focusedColumn: NSTableColumn?
    var asc: Bool?
    
    let numberFormatter = NSNumberFormatter()
    let dateFormatter = NSDateComponentsFormatter()
    let sizeFormatter = NSByteCountFormatter()
    let fileManager = NSFileManager.defaultManager()
    
    
    
    //initialize managed object context
    
    
    lazy var managedContext: NSManagedObjectContext = {
        return (NSApplication.sharedApplication().delegate
            as? AppDelegate)?.managedObjectContext }()!
    
    lazy var sourceListHeaderNodes: [SourceListItem]? = {()-> [SourceListItem]? in
        let fetchRequest = NSFetchRequest(entityName: "SourceListItem")
        let fetchPredicate = NSPredicate(format: "parent == nil")
        fetchRequest.predicate = fetchPredicate
        do {
            let results = try self.managedContext.executeFetchRequest(fetchRequest) as! [SourceListItem]
            for headerNode in results {
                if (headerNode as! SourceListItem).name == "Playlists" {
                    self.sourceListTreeController.playlistHeaderNode = headerNode
                }
            }
            return results
        } catch {
            print("error getting header nodes: \(error)")
            return nil
        }
    }()
    
    lazy var cachedOrders: [CachedOrder] = {
        let fetch_request = NSFetchRequest(entityName: "CachedOrder")
        var result = [CachedOrder]()
        do {
            let thing = try self.managedContext.executeFetchRequest(fetch_request) as! [CachedOrder]
            if thing.count != 0 {
                return thing
            }
        }
        catch {
            print("err")
        }
        return result
    }()

    
    
    
    //sort descriptors for source list
    var sourceListSortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "sort_order", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
    
    var librarySortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "artist_sort_order", ascending: true)]
    
    @IBAction func importButtonPressed(sender: AnyObject) {
        importWindowController = ImportWindowController(windowNibName: "ImportWindowController")
        importWindowController?.mainWindowController = self
        importWindowController?.showWindow(self)
    }
    //the view coordinator
    var viewCoordinator: ViewCoordinator?
    var currentSourceListItem: SourceListItem?
    
    func searchFieldDidStartSearching(sender: NSSearchField) {
        viewCoordinator?.search_bar_content = searchField.stringValue
    }
    func searchFieldDidEndSearching(sender: NSSearchField) {
        viewCoordinator?.search_bar_content = ""
    }
    
    //outline view stuff
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        if (item.representedObject!! as! SourceListItem).is_header == true {
            return outlineView.makeViewWithIdentifier("HeaderCell", owner: self)
        }
        else if (item.representedObject!! as! SourceListItem).playlist != nil {
            return outlineView.makeViewWithIdentifier("PlaylistCell", owner: self)
        }
        else if (item.representedObject!! as! SourceListItem).network_library != nil {
            return outlineView.makeViewWithIdentifier("NetworkLibraryCell", owner: self)
        }
        else if (item.representedObject!! as! SourceListItem).playlist_folder != nil {
            return outlineView.makeViewWithIdentifier("SongCollectionFolder", owner: self)
        }
        else if (item.representedObject!! as! SourceListItem).master_playlist != nil {
            return outlineView.makeViewWithIdentifier("MasterPlaylistCell", owner: self)
        }
        else {
            return outlineView.makeViewWithIdentifier("PlaylistCell", owner: self)
        }
    }
    
    func outlineViewSelectionDidChange(notification: NSNotification) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let selection = (sourceListTreeController.selectedNodes[0].representedObject! as! SourceListItem)
        if selection.master_playlist != nil {
            auxPlaylistScrollView.hidden = true
            libraryTableScrollView.hidden = false
            currentArrayController = tableViewArrayController
            currentTableView = libraryTableView
            focus = .library
            updateInfo()
            CATransaction.commit()
            return
        }
        let selection_name = selection.name!
        cur_view_title = selection_name
        print("selection name is \(selection_name)")
        if auxPlaylistTableView.windowIdentifier == selection_name {
            libraryTableScrollView.hidden = true
            auxPlaylistScrollView.hidden = false
            currentArrayController = auxPlaylistArrayController
            currentTableView = auxPlaylistTableView
            focus = .playlist
            updateInfo()
            CATransaction.commit()
        }
        else {
            if (selection.playlist?.track_id_list != nil) {
                let id_array = selection.playlist?.track_id_list
                auxPlaylistArrayController.fetchPredicate = NSPredicate(format: "id in %@", id_array!)
            }
            else {
                auxPlaylistArrayController.fetchPredicate = NSPredicate(format: "id in {}")
            }
            focus = .playlist
            auxPlaylistTableView.reloadData()
            libraryTableScrollView.hidden = true
            auxPlaylistScrollView.hidden = false
            currentArrayController = auxPlaylistArrayController
            currentTableView = auxPlaylistTableView
            CATransaction.commit()
            updateInfo()
            return
        }
    }

    //track queue, source logic
    @IBAction func toggleExpandQueue(sender: AnyObject) {
        if queueButton.state == NSOnState {
            queueScrollView.hidden = false
        }
        else if queueButton.state == NSOffState {
            queueScrollView.hidden = true
        }

    }
    func checkQueueList(track_played: Track) {
        initializeArray(track_played)
        cur_source_title = cur_view_title
    }
    
    func initializeArray(track_played: Track) {
        print("initialize array called")
        trackQueueTableDelegate.updateContext(cur_view_title)
        if cur_source_title != cur_view_title {
            current_source_play_order = (currentArrayController!.arrangedObjects as! [Track]).map( { return $0.id as! Int} )
        }
        
        if (shuffleButton.state == NSOnState) {
            print("shuffling")
            current_source_temp_shuffle = current_source_play_order
            shuffle_array(&current_source_temp_shuffle!)
            current_source_temp_shuffle = current_source_temp_shuffle!.filter( {
                $0 != track_played.id
            })
            current_source_index = 0
        }
        else {
            current_source_index = (current_source_play_order?.indexOf(Int(track_played.id!)))! + 1
            print("current source index:" + String(current_source_index))
        }
        is_initialized = true
    }
    
    func getNextTrack() -> Track? {
        var id: Int?
        if current_source_play_order!.count == current_source_index {
            return nil
        }
        if (shuffleButton.state == NSOnState) {
            id = current_source_temp_shuffle![current_source_index!]
        }
        else {
            id = current_source_play_order![current_source_index!]
        }
        let next_track = getTrackWithID(id!)
        currentTrack = next_track
        current_source_index! += 1
        return next_track
    }
    
    func getTrackWithID(id: Int) -> Track? {
        let fetch_req = NSFetchRequest(entityName: "Track")
        let pred = NSPredicate(format: "id == \(id)")
        fetch_req.predicate = pred
        let result: Track? = {() -> Track? in
            do {
                return try (managedContext.executeFetchRequest(fetch_req) as! [Track])[0]
            }
            catch {
                return nil
            }
        }()
        return result
    }
    
    @IBAction func shuffleButtonPressed(sender: AnyObject) {
        if (shuffleButton.state == NSOnState) {
            print("shuffling")
            current_source_temp_shuffle = current_source_play_order
            shuffle_array(&current_source_temp_shuffle!)
            if (currentTrack != nil) {
                current_source_temp_shuffle = current_source_temp_shuffle!.filter( {
                    $0 != currentTrack!.id
                })
            }
            current_source_index = 0
        }
        else {
            if currentTrack != nil {
                current_source_index = (current_source_play_order?.indexOf(Int(currentTrack!.id!)))! + 1
            } else {
            }
            print("current source index:" + String(current_source_index))
        }
    }
    
    
    func jumpToSelection() {
        libraryTableView.scrollRowToVisible(libraryTableView.selectedRow)
    }
    
    @IBAction func addPlaylistButton(sender: AnyObject) {
        let playlist = NSEntityDescription.insertNewObjectForEntityForName("SongCollection", inManagedObjectContext: managedContext) as! SongCollection
        let playlistItem = NSEntityDescription.insertNewObjectForEntityForName("SourceListItem", inManagedObjectContext: managedContext) as! SourceListItem
        playlistItem.playlist = playlist
        playlistItem.name = "New Playlist"
        playlistItem.parent = sourceListTreeController.playlistHeaderNode
        sourceListView.reloadData()
        sourceListTreeController.setSelectionIndexPath(sourceListTreeController.indexPathOfObject(playlistItem))
        sourceListView.editColumn(0, row: sourceListView.selectedRow, withEvent: nil, select: true)
    }
    
    //player stuff
    @IBAction func makePlaylistFromTrackQueueSelection(sender: AnyObject) {
        trackQueueTableDelegate.makePlaylistFromSelection()
    }
    
    func tableViewDoubleClick(sender: AnyObject) {
        guard currentTableView!.selectedRow >= 0 , let item = (currentArrayController!.selectedObjects) else {
            return
        }
        playSong(item[0] as! Track)
    }
    
    @IBAction func toggleArtwork(sender: AnyObject) {
        if artworkToggle.state == NSOnState {
            albumArtBox.hidden = false
        }
        else {
            albumArtBox.hidden = true
        }
    }
    @IBAction func togglePastTracks(sender: AnyObject) {
        trackQueueTableDelegate.togglePastTracks()
    }
    @IBAction func getInfoFromTableView(sender: AnyObject) {
        tagWindowController = TagEditorWindow(windowNibName: "TagEditorWindow")
        tagWindowController?.mainWindowController = self
        tagWindowController?.selectedTracks = currentArrayController!.selectedObjects as! [Track]
        tagWindowController?.showWindow(self)
    }
    @IBAction func addToQueueFromTableView(sender: AnyObject) {
        print(currentTableView!.selectedRow)
        let track_to_add = currentArrayController!.content!.objectAtIndex(currentTableView!.selectedRow) as! Track
        trackQueueTableDelegate.addTrackToQueue(track_to_add, context: cur_view_title, tense: 1)
        queue.addTrackToQueue(track_to_add, index: nil)
        checkQueueList(track_to_add)
    }
    @IBAction func playFromTableView(sender: AnyObject) {
        print(currentTableView!.selectedRow)
        let track_to_play = currentArrayController!.content!.objectAtIndex(currentTableView!.selectedRow) as! Track
        playSong(track_to_play)
        checkQueueList(track_to_play)
    }
    func playSong(track: Track) {
        if (paused == true && queue.is_initialized == true) {
            unpause()
        }
        trackQueueTableDelegate.changeCurrentTrack(track, context: cur_source_title)
        checkQueueList(track)
        queue.playImmediately(track)
        initializePlayerBarForNewTrack()
        print("about to init album art")
        currentTrack = track
    }
    
    func shuffle_array(inout array: [Int]) {
        for i in 0..<array.count - 1 {
            let j = Int(arc4random_uniform(UInt32(array.count - i))) + i
            guard i != j else {continue}
            swap(&array[i], &array[j])
        }
    }
    
    func tableView(tableView: NSTableView, mouseDownInHeaderOfTableColumn tableColumn: NSTableColumn) {
        print("called")
        print("caching \(tableColumn.identifier)")
        NSUserDefaults.standardUserDefaults().setObject(tableColumn.title, forKey: "lastColumn")
        if focusedColumn == tableColumn {
            tableViewArrayController.content = (tableViewArrayController.content as! [Track]).reverse()
            if asc == true {
                tableView.setIndicatorImage(NSImage(named: "NSDescendingSortIndicator"), inTableColumn: tableColumn)
                asc = false
            }
            else {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                asc = true
            }
        }
        else {
            if focusedColumn != nil {
                tableView.setIndicatorImage(nil, inTableColumn: focusedColumn!)
            }
            if tableColumn.title == "Artist" {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                print("here")
                tableViewArrayController.content = cachedOrders.filter( {return $0.order == "Artist"})[0].tracks?.array
                asc = true
                focusedColumn = tableColumn
            }
            else if tableColumn.title == "Album" {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                print("here")
                tableViewArrayController.content = cachedOrders.filter( {return $0.order == "Album"})[0].tracks?.array
                asc = true
                focusedColumn = tableColumn
            }
            else if tableColumn.title == "Date Added" {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                print("here")
                tableViewArrayController.content = cachedOrders.filter( {return $0.order == "Date Added"})[0].tracks?.array
                asc = true
                focusedColumn = tableColumn
            }
            else if tableColumn.title == "Time" {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                print("here")
                tableViewArrayController.content = cachedOrders.filter( {return $0.order == "Time"})[0].tracks?.array
                asc = true
                focusedColumn = tableColumn
            }
            else if tableColumn.title == "Name" {
                tableView.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
                print("here")
                tableViewArrayController.content = cachedOrders.filter( {return $0.order == "Name"})[0].tracks?.array
                asc = true
                focusedColumn = tableColumn
            }
        }
        print(tableViewArrayController.selectedObjects)
        print(libraryTableView.selectedRowIndexes)
        NSUserDefaults.standardUserDefaults().setBool(asc!, forKey: "currentAsc")
        tableView.reloadData()
    }
    
    func refreshTableView() {
        let column = focusedColumn
        focusedColumn = nil
        tableView(currentTableView!, mouseDownInHeaderOfTableColumn: column!)
    }
    
    func pause() {
        updateValuesUnsafe()
        timer?.invalidate()
        paused = true
        queue.pause()
    }
    
    func unpause() {
        lastTimerDate = NSDate()
        paused = false
        queue.play()
        timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(updateValuesSafe), userInfo: nil, repeats: true)
    }
    
    func seek(frac: Double) {
        queue.seek(frac)
    }
    
    func skip() {
        timer?.invalidate()
        queue.skip()
    }
    
    func skipBackward() {
        timer?.invalidate()
        queue.skip_backward()
    }
    
    override func keyDown(theEvent: NSEvent) {
        print(theEvent.keyCode)
        if (theEvent.keyCode == 36) {
            guard currentTableView!.selectedRow >= 0 , let item = (currentArrayController!.selectedObjects) else {
                return
            }
            playSong(item[0] as! Track)
        }
        else if theEvent.keyCode == 124 {
            skip()
        }
        else if theEvent.keyCode == 123 {
            skipBackward()
        }
    }
    
    
    @IBAction func playPressed(sender: AnyObject) {
        print("called")
        if (paused == true) {
            //if not initialized, play selected track/shuffle
            unpause()
            paused = false
        }
        else {
            pause()
            paused = true
        }
    }
    
    @IBAction func toggleFilterVisibility(sender: AnyObject) {
        if advancedFilterScrollView.hidden == true {
            advancedFilterScrollView.hidden = false
        }
        else if advancedFilterScrollView.hidden == false {
            advancedFilterScrollView.hidden = true
        }
    }
    
    @IBAction func testyThing(sender: AnyObject) {
        advancedFilterScrollView.hidden = false
    }
    
    func initializePlayerBarForNewTrack() {
        print("paused value in mwc is \(paused)")
        timer?.invalidate()
        theBox.contentView!.hidden = false
        let the_track = queue.currentTrack!
        currentTrack = the_track
        initAlbumArt(the_track)
        if the_track.name != nil {
            songNameLabel.stringValue = the_track.name!
        }
        var aa_string = ""
        if the_track.artist != nil {
            aa_string += (the_track.artist! as Artist).name!
            if the_track.album != nil {
                aa_string += (" - " + (the_track.album! as Album).name!)
            }
        }
        artistAlbumLabel.stringValue = aa_string
        duration = queue.duration_seconds
        durationLabel.stringValue = getTimeAsString(duration!)
        currentTimeLabel.stringValue = getTimeAsString(0)
        lastTimerDate = NSDate()
        secsPlayed = 0
        progressBar.hidden = false
        progressBar.doubleValue = 0
        if (paused == false || paused == nil) {
            startTimer()
        }
    }
    
    func startTimer() {
        //timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(updateValuesUnsafe), userInfo: nil, repeats: true)
        timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(updateValuesSafe), userInfo: nil, repeats: true)
    }
    
    func updateValuesUnsafe() {
        print("unsafe called")
        let nodeTime = queue.curNode.lastRenderTime
        let playerTime = queue.curNode.playerTimeForNodeTime(nodeTime!)
        var offset_thing: Double?
        if queue.track_frame_offset == nil {
            offset_thing = 0
        }
        else {
            offset_thing  = queue.track_frame_offset!
        }
        let seconds = ((Double((playerTime?.sampleTime)!) + offset_thing!) / (playerTime?.sampleRate)!) - Double(queue.total_offset_seconds)
        let seconds_string = getTimeAsString(seconds)
        if (timer?.valid == true) {
            currentTimeLabel.stringValue = seconds_string
            progressBar.doubleValue = (seconds * 100) / duration!
        }
        else {
            currentTimeLabel.stringValue = ""
            progressBar.doubleValue = 0
        }
        secsPlayed = seconds
    }
    
    func updateValuesSafe() {
        print("safe called")
        let lastUpdateTime = lastTimerDate
        let currentTime = NSDate()
        let updateQuantity = currentTime.timeIntervalSinceDate(lastUpdateTime!)
        print(updateQuantity)
        secsPlayed += updateQuantity
        let seconds_string = getTimeAsString(secsPlayed)
        if timer?.valid == true {
            currentTimeLabel.stringValue = seconds_string
            progressBar.doubleValue = (secsPlayed * 100) / duration!
        } else {
            currentTimeLabel.stringValue = ""
            progressBar.doubleValue = 0
        }
        lastTimerDate = currentTime
    }
    
    func cleanUpBar() {
        theBox.contentView!.hidden = true
        songNameLabel.stringValue = ""
        artistAlbumLabel.stringValue = ""
        duration = 0
        durationLabel.stringValue = ""
        currentTimeLabel.stringValue = ""
        progressBar.doubleValue = 100
    }
    
    func expandSourceView() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            dispatch_async(dispatch_get_main_queue()) {
            self.sourceListView.expandItem(nil, expandChildren: true)
            self.sourceListView.selectRowIndexes(NSIndexSet.init(index: 1),byExtendingSelection: false)
            print("executed this block")
            }
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &my_context {
            if keyPath! == "track_changed" {
                print("controller detects track change")
                timer?.invalidate()
                initializePlayerBarForNewTrack()
                trackQueueTableDelegate.nextTrack()
            }
            else if keyPath! == "done_playing" {
                print("controller detects finished playing")
                cleanUpBar()
            }
            else if keyPath! == "sortDescriptors" {
                if (cur_view_title == cur_source_title) {
                    current_source_play_order = (currentArrayController!.arrangedObjects as! [Track]).map( {return $0.id as! Int} )
                    if (is_initialized == true) {
                        current_source_index = (currentArrayController!.arrangedObjects as! [Track]).indexOf(currentTrack!)
                        print("current source index set to \(current_source_index)")
                    }
                }
            }
            else if keyPath! == "filterPredicate" {
                if (cur_view_title == cur_source_title) {
                    current_source_play_order = (currentArrayController!.arrangedObjects as! [Track]).map( {return $0.id as! Int} )
                    if (is_initialized == true) {
                        current_source_index = (currentArrayController!.arrangedObjects as! [Track]).indexOf(currentTrack!)
                        if current_source_index == nil {
                            current_source_index = 0
                        }
                        print("current source index set to \(current_source_index)")
                    }
                }
            }
            updateInfo()
        }
    }
    
    func updateInfo() {
        print("called")
        let trackArray = currentArrayController?.arrangedObjects as! [Track]
        let numItems = trackArray.count
        let totalSize = trackArray.map({return ($0.size!.longLongValue)}).reduce(0, combine: {$0 + $1})
        let totalTime = trackArray.map({return $0.time!.doubleValue}).reduce(0, combine: {$0 + $1})
        let numString = numberFormatter.stringFromNumber(numItems)
        let sizeString = sizeFormatter.stringFromByteCount(totalSize)
        let timeString = dateFormatter.stringFromTimeInterval(totalTime/1000)
        infoString = "\(numString!) items; \(timeString!); \(sizeString)"
        infoField.stringValue = infoString!
    }
    
    

    @IBAction func trackListTriangleClicked(sender: AnyObject) {
        if trackListBox.hidden == true {
            trackListBox.hidden = false
        }
        else if trackListBox.hidden == false {
            trackListBox.hidden = true
        }
        
    }
    
    //mark album art
    
    func initAlbumArt(track: Track) {
        if track.album != nil && track.album!.primary_art != nil {
            print("here")
            let art = track.album!.primary_art
            let path = art?.artwork_location as! String
            let url = NSURL(fileURLWithPath: path)
            let image = NSImage(contentsOfURL: url)
            albumArtView.image = image
        }
        else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                var artworkFound = false
                if NSUserDefaults.standardUserDefaults().boolForKey("checkEmbeddedArtwork") == true {
                    print("checking mp3 for embedded art")
                    let artwork = (NSApplication.sharedApplication().delegate as! AppDelegate).yeOldeFileHandler?.getArtworkFromFile(track.location!)
                    if artwork != nil {
                        let albumDirectoryPath = NSURL(string: track.location!)?.URLByDeletingLastPathComponent
                        if addPrimaryArtForTrack(track, art: artwork!, albumDirectoryPath: albumDirectoryPath!.path!) != nil {
                            dispatch_async(dispatch_get_main_queue()) {
                                self.initAlbumArt(track)
                            }
                            artworkFound = true
                        }
                    }
                }
                if NSUserDefaults.standardUserDefaults().boolForKey("findAlbumArtwork") == true && artworkFound == false {
                    print("requesting art")
                    let requester = artAPIRequestDelegate()
                    requester.artAPIRequest(track)
                }
                if artworkFound == false {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.albumArtView.image = nil
                    }
                }
            }
        }
        /*if track.album?.other_art != nil {
            artCollectionView.hidden = false
            artCollectionView.dataSource = artCollectionArrayController
            artCollectionArrayController.content = track.album!.other_art!.art!.mutableCopy().array
            
        }*/
    }
    
    override func awakeFromNib() {
        /*sourceListView.expandItem(nil, expandChildren: true)
        sourceListView.selectRowIndexes(NSIndexSet.init(index: 1), byExtendingSelection: false)
        dispatch_async(dispatch_get_main_queue()) {
            self.sourceListView.expandItem(nil, expandChildren: exptrue)
            self.sourceListView.selectRowIndexes(NSIndexSet.init(index: 1), byExtendingSelection: false)
            print("executed this block")
        }*/
    }
    
    
    override func windowDidLoad() {
        numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
        dateFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyle.Full
        print(hasMusic)
        if (hasMusic == false) {
            noMusicView.hidden = false
            libraryTableScrollView.hidden = true
            sourceListView.hidden = true
        }
        queue.mainWindowController = self
        //shuffle = shuffleButton.state
        progressBar.displayedWhenStopped = true
        progressBarView.progressBar = progressBar
        progressBarView.mainWindowController = self
        sourceListView.setDelegate(self)
        sourceListView.setDataSource(sourceListTreeController)
        sourceListScrollView.drawsBackground = false
        theBox.contentView?.hidden = true
        /*theBox.boxType = .Custom
        theBox.borderType = .BezelBorder
        theBox.borderWidth = 1.1
        theBox.cornerRadius = 3*/
        //theBox.fillColor = NSColor(patternImage: NSImage(named: "Gradient")!)
        libraryTableView.doubleAction = "tableViewDoubleClick:"
        libraryTableView.setDelegate(self)
        libraryTableView.setDataSource(tableViewArrayController)
        tableViewArrayController.mainWindow = self
        print(libraryTableView.registeredDraggedTypes)
        sourceListView.mainWindowController = self
        libraryTableView.mainWindowController = self
        auxPlaylistTableView.mainWindowController = self
        searchField.delegate = self
        //libraryTableView.tableColumns[4].sortDescriptorPrototype = NSSortDescriptor(key: "artist_sort_order", ascending: true)
        //libraryTableView.tableColumns[5].sortDescriptorPrototype = NSSortDescriptor(key: "album_sort_order", ascending: true)
        libraryTableView.setDelegate(self)
        queue.addObserver(self, forKeyPath: "track_changed", options: .New, context: &my_context)
        queue.addObserver(self, forKeyPath: "done_playing", options: .New, context: &my_context)
        tableViewArrayController.addObserver(self, forKeyPath: "sortDescriptors", options: .New, context: &my_context)
        tableViewArrayController.addObserver(self, forKeyPath: "filterPredicate", options: .New, context: &my_context)
        super.windowDidLoad()
        if (hasMusic == true) {
            print(cachedOrders[0])
        }
        albumArtView.mainWindowController = self
        trackQueueTableView.setDataSource(trackQueueTableDelegate)
        trackQueueTableView.setDelegate(trackQueueTableDelegate)
        trackQueueTableDelegate.tableView = trackQueueTableView
        let currentColumn = NSUserDefaults.standardUserDefaults().objectForKey("lastColumn")
        let currentAsc = NSUserDefaults.standardUserDefaults().boolForKey("currentAsc")
        print("retrieving \(currentColumn) from cache")
        trackQueueTableView.registerForDraggedTypes(["Track", "public.TrackQueueView"])
        trackQueueTableDelegate.mainWindowController = self
        queueScrollView.hidden = true
        
        currentTableView = libraryTableView
        volumeSlider.continuous = true
        artCollectionView.hidden = true
        //predicateEditor.rowTemplates = rowTemplates
        //predicateEditor.addRow(nil)
        self.window!.titleVisibility = NSWindowTitleVisibility.Hidden
        self.window!.titlebarAppearsTransparent = true
        if currentColumn != nil {
            let columnTest = NSTableColumn()
            columnTest.title = currentColumn as! String
            tableView(libraryTableView, mouseDownInHeaderOfTableColumn: columnTest)
            if (currentAsc == false) {
                tableView(libraryTableView, mouseDownInHeaderOfTableColumn: columnTest)
            }
        }
        else {
            if hasMusic == true {
                tableViewArrayController.content = cachedOrders[4].tracks?.array
            }
        }
        current_source_play_order = (tableViewArrayController.content as! [Track]).map( {return $0.id as! Int})
        print(current_source_play_order!.count)
        currentArrayController = tableViewArrayController
        updateInfo()
        //currentArrayController?.rearrangeObjects()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            dispatch_async(dispatch_get_main_queue()) {
                self.sourceListView.expandItem(nil, expandChildren: true)
            }
        }
        let mainLibraryIndexes = [0, 0]
        let mainLibraryIndexPath = NSIndexPath(indexes: mainLibraryIndexes, length: 2)
        sourceListTreeController.setSelectionIndexPath(mainLibraryIndexPath)
        //sourceListTreeController.content = sourceListHeaderNodes
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "findAlbumArtwork")
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "checkEmbeddedArtwork")
    }
}
