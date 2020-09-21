
#this performs registration from subject b0 to template b0, without using any existing mask
rule ants_b0_to_template:
    input:  
        flo = bids(root='results',suffix='b0.nii.gz',desc='topup',method='jac',**subj_wildcards),
        ref = config['template_b0'],
        init_xfm = bids(root='results',subfolder='reg_t1_to_template',subject='{subject}',suffix='xfm.txt',from_='subject',to='{template}',desc='affine',type_='itk'),
    params:
        out_prefix = bids(root='results',subfolder='reg_b0_to_template',suffix='',from_='subject',to='{template}',subject='{subject}'),
        base_opts = '--write-composite-transform -d {dim} '.format(dim=config['ants']['dim']),
        intensity_opts = config['ants']['intensity_opts'],
        init_transform = lambda wildcards, input: '-r {xfm}'.format(xfm=input.init_xfm),
        linear_multires = '-c [{reg_iterations},1e-6,10] -f {shrink_factors} -s {smoothing_factors}'.format(
                                reg_iterations = config['ants']['linear']['reg_iterations'],
                                shrink_factors = config['ants']['linear']['shrink_factors'],
                                smoothing_factors = config['ants']['linear']['smoothing_factors']),
        deform_model = '-t {deform_model}'.format(deform_model = config['ants']['deform']['transform_model']),
        deform_multires = '-c [{reg_iterations},1e-9,10] -f {shrink_factors} -s {smoothing_factors}'.format(
                                reg_iterations = config['ants']['deform']['reg_iterations'],
                                shrink_factors = config['ants']['deform']['shrink_factors'],
                                smoothing_factors = config['ants']['deform']['smoothing_factors']),
        deform_metric = lambda wildcards, input: '-m {metric}[{template},{target},1,4]'.format(
                                metric=config['ants']['deform']['sim_metric'],
                                template=input.ref, target=input.flo),
        linear_metric = lambda wildcards, input: '-m MI[{template},{target},1,32,Regular,0.25]'.format(
                                template=input.ref, target=input.flo)

    output:
        out_composite = bids(root='results',subfolder='reg_b0_to_template',suffix='Composite.h5',from_='subject',to='{template}',subject='{subject}'),
        out_inv_composite = bids(root='results',subfolder='reg_b0_to_template',suffix='InverseComposite.h5',from_='subject',to='{template}',subject='{subject}'),
        warped_flo = bids(root='results',subfolder='reg_b0_to_template',suffix='b0.nii.gz',space='{template}',desc='SyN',subject='{subject}'),
    threads: 8
    resources:
        mem_mb = 16000, # right now these are on the high-end -- could implement benchmark rules to do this at some point..
        time = 60 # 1 hrs
    container: config['singularity']['prepdwi']
    group: 'preproc'
    shell: 
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsRegistration {params.base_opts} {params.intensity_opts} '
        '{params.init_transform} ' #initial xfm  
        '-t Affine[0.1] {params.linear_metric} {params.linear_multires} ' # affine registration
        '{params.deform_model} {params.deform_metric} {params.deform_multires} '  # deformable registration
        '-o [{params.out_prefix},{output.warped_flo}]'
       

#now, we apply the transform to template mask to get what should be an accurate registration-based b0 mask
rule warp_brainmask_from_template_reg_b0:
    input: 
        mask = config['template_mask'],
        ref = bids(root='results',suffix='b0.nii.gz',desc='topup',method='jac',**subj_wildcards),
        inv_composite = bids(root='results',subfolder='reg_b0_to_template',suffix='InverseComposite.h5',from_='subject',to='{template}',subject='{subject}'),
    output:
        mask = bids(root='results',subfolder='reg_b0_to_template',subject='{subject}',suffix='mask.nii.gz',from_='{template}',reg='SyN',desc='brain'),
    container: config['singularity']['prepdwi']
    group: 'preproc'
    threads: 1
    resources:
        mem_mb = 16000
    shell: 
        'ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS={threads} '
        'antsApplyTransforms -d 3 --interpolation NearestNeighbor -i {input.mask} -o {output.mask} -r {input.ref} '
            ' -t {input.inv_composite} ' #use inverse xfm (going from template to subject)

#copy to the main folder
rule cp_brainmask_reg_b0:
    input:
        mask = bids(root='results',subfolder='reg_b0_to_template',subject='{subject}',suffix='mask.nii.gz',from_='{template}',reg='SyN',desc='brain'),
    output:
        mask = bids(root='results',method='b0SyN',subject='{subject}',suffix='mask.nii.gz',from_='{template}',desc='brain'),
    shell:
        'cp -v {input} {output}'



