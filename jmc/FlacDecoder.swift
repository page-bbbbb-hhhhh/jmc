//
//  FlacDecoder.swift
//  jmc
//
//  Created by John Moody on 2/15/17.
//  Copyright © 2017 John Moody. All rights reserved.
//

import Foundation
import AVFoundation

class FlacDecoder {
    
    var decoder: FLAC__StreamDecoder?
    var blockBuffer = [Int32]()
    var sampleRate: UInt32?
    var channels: UInt32?
    var bitsPerSample: UInt32?
    var totalFrames: UInt64?
    
    private var my_client_data = 0
    
    
    let flacWriteCallback: @convention(c) (Optional<UnsafePointer<FLAC__StreamDecoder>>, Optional<UnsafePointer<FLAC__Frame>>, Optional<UnsafePointer<Optional<UnsafePointer<Int32>>>>, Optional<UnsafeMutableRawPointer>) -> FLAC__StreamDecoderWriteStatus = {
        (decoder: Optional<UnsafePointer<FLAC__StreamDecoder>>, frame: Optional<UnsafePointer<FLAC__Frame>>, buffer: Optional<UnsafePointer<Optional<UnsafePointer<Int32>>>>, client_data: Optional<UnsafeMutableRawPointer>) -> FLAC__StreamDecoderWriteStatus in
        
        let flacDecoder = Unmanaged<FlacDecoder>.fromOpaque(client_data!).takeUnretainedValue()
        
        let numSamples = frame!.pointee.header.blocksize
        let numChannels = frame!.pointee.header.channels
        for sampleIndex in 0..<numSamples {
            for channelIndex in 0..<numChannels {
                flacDecoder.blockBuffer.append(buffer![Int(channelIndex)]![Int(sampleIndex)])
            }
        }
        return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
    }
    
    let flacMetadataCallback: @convention(c) (Optional<UnsafePointer<FLAC__StreamDecoder>>, Optional<UnsafePointer<FLAC__StreamMetadata>>, Optional<UnsafeMutableRawPointer>) -> () = {
        (decoder: Optional<UnsafePointer<FLAC__StreamDecoder>>, metadata: Optional<UnsafePointer<FLAC__StreamMetadata>>, client_data: Optional<UnsafeMutableRawPointer>) in
        let flacDecoder = Unmanaged<FlacDecoder>.fromOpaque(client_data!).takeUnretainedValue()
        let meta = metadata!.pointee
        switch meta.type {
        case FLAC__METADATA_TYPE_STREAMINFO:
            flacDecoder.channels = meta.data.stream_info.channels
            flacDecoder.sampleRate = meta.data.stream_info.sample_rate
            flacDecoder.bitsPerSample = meta.data.stream_info.bits_per_sample
            flacDecoder.totalFrames = meta.data.stream_info.total_samples
        default:
            print("doingus")
        }
        
        
    }
    
    let flacErrorCallback: @convention(c) (Optional<UnsafePointer<FLAC__StreamDecoder>>, FLAC__StreamDecoderErrorStatus, Optional<UnsafeMutableRawPointer>) -> () = {
        (decoder: Optional<UnsafePointer<FLAC__StreamDecoder>>, status: FLAC__StreamDecoderErrorStatus, client_data: Optional<UnsafeMutableRawPointer>) in
        
    }
    
    func createFLACStreamDecoder(file: URL) -> Bool {
        let flacStreamDecoder = FLAC__stream_decoder_new()
        self.decoder = flacStreamDecoder?.pointee
        FLAC__stream_decoder_set_metadata_respond(flacStreamDecoder, FLAC__METADATA_TYPE_VORBIS_COMMENT)
        FLAC__stream_decoder_set_metadata_respond(flacStreamDecoder, FLAC__METADATA_TYPE_PICTURE)
        let pointerToSelf = Unmanaged.passRetained(self).toOpaque()
        let initResult = FLAC__stream_decoder_init_file(flacStreamDecoder, file.path, flacWriteCallback, flacMetadataCallback, flacErrorCallback, pointerToSelf)
        if initResult == FLAC__STREAM_DECODER_INIT_STATUS_OK {
            FLAC__stream_decoder_process_until_end_of_metadata(flacStreamDecoder)
            return true
        } else {
            print(initResult)
            return false
        }
    }
    
    func readFLAC(file: URL) -> AVAudioPCMBuffer? {
        if createFLACStreamDecoder(file: file) == true {
            FLAC__stream_decoder_process_until_end_of_metadata(&self.decoder!)
            let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt32, sampleRate: Double(self.sampleRate!), channels: self.channels!, interleaved: true), frameCapacity: AVAudioFrameCount(self.totalFrames! * UInt64(self.channels!)))
            FLAC__stream_decoder_process_until_end_of_stream(&self.decoder!)
            buffer.int32ChannelData!.pointee.initialize(from: self.blockBuffer)
            buffer.frameLength = buffer.frameCapacity
            return buffer
        } else {
            print("failure")
            return nil
        }
    }
}
