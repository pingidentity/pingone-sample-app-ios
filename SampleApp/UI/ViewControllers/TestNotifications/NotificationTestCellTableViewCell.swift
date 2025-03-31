//
//  NotificationTestCellTableViewCell.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import UIKit

class NotificationTestCellTableViewCell: UITableViewCell {

    @IBOutlet weak var testNameLbl: UILabel!
    @IBOutlet weak var apnsTypeLbl: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var resultImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
